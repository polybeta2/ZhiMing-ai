#if os(iOS) || os(macOS)
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
import ZhiMingCore

/// 同人原作扫描流程状态机：驱动切章分块 + 逐块 Map + 两段 Reduce，
/// 把进度映射为 UI 状态（阶段/块进度/token），并做 SQLite 断点续传（chunk 粒度）。
/// 按计划约定：本 VM 直接循环 OpenAICompatibleClient（真实流式喂 progress），
/// 不调用 SourceScanEngine（引擎保留供 Core 单测断言契约）。
@MainActor
final class SourceScanViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle, splitting, mapping, reducing, done, paused, failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var doneChunks = 0
    @Published private(set) var totalChunks = 0
    @Published private(set) var tokensIn = 0
    @Published private(set) var tokensOut = 0
    @Published private(set) var stageSummaries: [String] = []
    /// 断点续传键：同一档案重扫沿用（换档重扫会 clear 后重置）
    @Published private(set) var profileID: UUID?
    @Published private(set) var resultProfile: SourceNovelProfile?
    /// 流式可视化：等待首Token/思考/输出统计（复用现有组件）
    let progress = StreamProgressTracker()

    /// 后台任务句柄（分析中申请保活，退到后台尽量多跑一点；仅 iOS）
    #if canImport(UIKit)
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    private var task: Task<Void, Never>?
    private var client: OpenAICompatibleClient?
    private var config: GenerationConfig?
    /// 当前服务商（可在暂停/失败后由进度页切换，下次 start 生效）
    private(set) var provider: ProviderConfig
    private let store: AppStore
    private var sourceText = ""
    private var sourceTitle = ""
    private var sourceChars = 0
    private var currentMode: ScanMode = .fast
    /// 续写模式：终归并改走深度归并（continuationPrompt），产物带伏笔/剧情弧/现状，并写原文边车
    private(set) var isContinuation = false
    /// 单次请求分析的章数（1 = 逐章，API 自动批量 >1）
    private(set) var batchSize = 1
    /// Map 计时（秒/章），用于剩余时间估算
    private var mapTimes: [TimeInterval] = []
    @Published private(set) var avgSecondsPerChunk: Double = 0
    @Published private(set) var estimatedRemainingSeconds: Int = 0

    init(provider: ProviderConfig, store: AppStore) {
        self.provider = provider
        self.store = store
    }

    /// 可切换的服务商列表（进度页换 provider 用）
    var availableProviders: [ProviderConfig] { store.providers }

    /// 更换服务商：仅未开始/已暂停/失败时可生效（下次 start/resume 使用新配置）
    func setProvider(_ newProvider: ProviderConfig) {
        guard phase == .idle || phase == .paused || isFailed else { return }
        provider = newProvider
    }

    /// 批量复制模式：外部 AI 已把 Map 结果落库到 presetProfileID（chunk 断点键），
    /// start 时沿用该键并跳过所有 done 块，直接走归并。
    var presetProfileID: UUID?

    var isFailed: Bool { if case .failed = phase { return true }; return false }

    var phaseLabel: String {
        switch phase {
        case .idle: return "准备中"
        case .splitting: return "切章分块中…"
        case .mapping: return "逐块提取中（Map）…"
        case .reducing: return isContinuation ? "深度归并档案中（人物快照/伏笔/剧情弧）…" : "归并档案中（Reduce）…"
        case .done: return "分析完成"
        case .paused: return "已暂停"
        case .failed(let message): return message
        }
    }

    /// 启动/恢复一次扫描：mode 决定档位；batchSize 决定单次请求分析的章数（1 = 逐章）。
    /// doneIndexes 从 SourceScanCache 恢复
    func start(graphText: String, title: String, mode: ScanMode, batchSize: Int = 1, continuation: Bool = false) {
        guard phase == .idle || phase == .paused || isFailed else { return }
        sourceText = graphText
        sourceTitle = title
        sourceChars = graphText.count
        currentMode = mode
        self.batchSize = max(1, min(batchSize, 10))
        self.isContinuation = continuation

        phase = .splitting
        let chunks = SourceScanChunker.chunks(from: graphText, mode: mode)
        totalChunks = chunks.count
        guard !chunks.isEmpty else { phase = .failed("未能从文本中切出章节，请检查文件内容"); return }

        // 断点键：批量复制沿用 preset 键（跳过已 done 直接归并）；普通扫描沿用暂停恢复；否则新建
        let pid = profileID ?? presetProfileID ?? UUID()
        profileID = pid

        // 任务书签：进程被杀后能识别的「未完成分析」+ 源文本（退出重进从断点续跑）
        ScanTaskBookmark.save(text: graphText, profileID: pid, title: title, mode: mode,
                              batchSize: self.batchSize, isContinuation: continuation,
                              totalChunks: chunks.count, provider: provider)
        // 分析期间向后台申请保活（退到后台系统额外给执行时间）
        beginBackgroundTask()

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            phase = .failed("未配置有效的模型接口或 API Key")
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        self.client = client
        self.config = GenerationConfig(temperature: 0.4, maxTokens: 3000)

        let done = SourceScanCache.doneIndexes(profile: pid)
        doneChunks = done.count
        let priorIn = tokensIn
        let priorOut = tokensOut

        phase = .mapping
        progress.begin()
        task = Task { [weak self] in
            await self?.runLoop(chunks: chunks, client: client, done: done, pid: pid,
                                priorIn: priorIn, priorOut: priorOut,
                                mapConfig: self?.config ?? GenerationConfig(temperature: 0.4, maxTokens: 3000),
                                reduceConfig: GenerationConfig(temperature: 0.4, maxTokens: 6000),
                                finalConfig: GenerationConfig(temperature: 0.3, maxTokens: 8000))
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        progress.finish()
        endBackgroundTask()      // 暂停：保留书签与 SQLite 缓存，可续跑
        phase = .paused
    }

    // MARK: - 后台保活（仅 iOS：申请后台执行时间，退到后台继续跑多一点）

    private func beginBackgroundTask() {
        #if canImport(UIKit)
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ZhiMing.scan") { [weak self] in
            self?.endBackgroundTask()
        }
        #endif
    }

    private func endBackgroundTask() {
        #if canImport(UIKit)
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
        #endif
    }

    func resume() {
        guard phase == .paused else { return }
        start(graphText: sourceText, title: sourceTitle, mode: sourceMode,
              batchSize: batchSize, continuation: isContinuation)
    }

    func reset() {
        task?.cancel()
        task = nil
        progress.finish()
        endBackgroundTask()
        phase = .idle
        doneChunks = 0
        totalChunks = 0
        tokensIn = 0
        tokensOut = 0
        stageSummaries = []
        profileID = nil
        resultProfile = nil
    }

    private var sourceMode: ScanMode { currentMode }

    // MARK: - 主循环（Map → 一段归并 → 二段终归并）

    /// 单次流式拉取：聚合正文；返回 (正文, 是否完整读到流尾)。
    /// 网络错误（504/openai_error 等）由调用方循环重试。
    private func fetch(_ msgs: [LLMMessage], client: OpenAICompatibleClient,
                       config: GenerationConfig) async -> (reply: String, drained: Bool) {
        var reply = ""
        do {
            for try await event in client.streamChat(messages: msgs, config: config) {
                progress.handle(event)
                if case .content(let delta) = event { reply += delta }
                if Task.isCancelled { break }
            }
            return (reply, true)
        } catch {
            return (reply, false)
        }
    }

    /// 解析 + 网络双重重试：最多 attempts 次（默认 3）。
    /// 返回 nil 表示网络全程失败（调用方暂停）；空摘要表示解析全程失败（降级不阻塞）
    private func fetchParsed(_ msgs: [LLMMessage], client: OpenAICompatibleClient,
                             config: GenerationConfig, attempts: Int = 3) async -> SourceMicroSummarizer.MicroSummary? {
        for _ in 0..<attempts {
            if Task.isCancelled { return nil }
            let (reply, drained) = await fetch(msgs, client: client, config: config)
            guard drained else { continue }                     // 网络错误 → 重试
            if let parsed = try? SourceMicroSummarizer.parse(reply) {
                return parsed
            }
            // 解析失败 → 重试
        }
        return nil
    }

    /// 网络重试（降级/归并用）：最多 attempts 次，全部读完即停止
    private func fetchWithRetry(_ msgs: [LLMMessage], client: OpenAICompatibleClient,
                                config: GenerationConfig, attempts: Int = 3) async -> (reply: String, drained: Bool) {
        for _ in 0..<attempts {
            if Task.isCancelled { return ("", false) }
            let (reply, drained) = await fetch(msgs, client: client, config: config)
            if drained { return (reply, true) }
        }
        return ("", false)
    }

    /// 批量解析（API 自动批量用）：网络/解析失败重试 3 次；
    /// 返回 nil 表示全败（调用方暂停）。key = 0-based 全书章序
    private func fetchBatchParsed(_ msgs: [LLMMessage], client: OpenAICompatibleClient,
                                  config: GenerationConfig, attempts: Int = 3) async -> [Int: SourceMicroSummarizer.MicroSummary]? {
        for _ in 0..<attempts {
            if Task.isCancelled { return nil }
            let (reply, drained) = await fetch(msgs, client: client, config: config)
            guard drained else { continue }
            if let parsed = try? SourceBatchHelper.parseBatchOutput(reply) {
                return parsed
            }
        }
        return nil
    }

    /// 剩余时间估算：平均秒/章 ×（总块 - 已完块）
    private func updateEstimate() {
        guard !mapTimes.isEmpty else { return }
        avgSecondsPerChunk = mapTimes.reduce(0, +) / Double(mapTimes.count)
        let remaining = max(0, totalChunks - doneChunks)
        estimatedRemainingSeconds = Int(avgSecondsPerChunk * Double(remaining))
    }

    /// 微摘要 token 近似（输出字符数 / 2）
    private func microChars(_ micro: SourceMicroSummarizer.MicroSummary) -> Int {
        ((try? String(data: JSONEncoder().encode(micro), encoding: .utf8))?.count ?? 0) / 2
    }

    private func runLoop(chunks: [SourceScanChunker.Chunk], client: OpenAICompatibleClient,
                         done: Set<Int>, pid: UUID, priorIn: Int, priorOut: Int,
                         mapConfig: GenerationConfig, reduceConfig: GenerationConfig,
                         finalConfig: GenerationConfig) async {
        var micros: [SourceMicroSummarizer.MicroSummary] = []
        var inTotal = priorIn
        var outTotal = priorOut

        // ---- Map：连续未完成块成组，一次请求分析 batchSize 章（跳过 done） ----
        var pos = 0
        while pos < chunks.count {
            if Task.isCancelled { break }
            if done.contains(pos) { pos += 1; continue }
            // 顺取本组：从 pos 起最多 batchSize 个未 done 块
            var group: [(pos: Int, chapter: Int, text: String)] = []
            var g = pos
            while g < chunks.count && group.count < batchSize {
                if done.contains(g) { break }
                group.append((g, chunks[g].chapterIndex, chunks[g].text))
                g += 1
            }
            guard !group.isEmpty else { pos += 1; continue }

            let t0 = Date()
            var groupSummary: [Int: SourceMicroSummarizer.MicroSummary] = [:]
            if group.count == 1 {
                // 逐章：沿用原协议（含角色系统提示）
                let single = group[0]
                let msgs = SourceMicroSummarizer.messages(chunk: single.text, chapterMarker: nil)
                let result = await fetchParsed(msgs, client: client, config: mapConfig)
                if result == nil {
                    await MainActor.run { [weak self] in self?.cancel() }
                    return
                }
                groupSummary[single.chapter] = result
            } else {
                // 批量：SourceBatchHelper 生成「指令 + N 章正文」，AI 逐章返回一行 JSON
                let batch = group.map { (index: $0.chapter + 1, title: nil as String?, body: $0.text) }
                let prompt = SourceBatchHelper.prompt(title: sourceTitle, chapters: batch)
                let msgs = [LLMMessage(role: .user, content: prompt)]
                guard let result = await fetchBatchParsed(msgs, client: client, config: mapConfig) else {
                    await MainActor.run { [weak self] in self?.cancel() }
                    return
                }
                groupSummary = result
            }
            let elapsed = Date().timeIntervalSince(t0)
            mapTimes.append(elapsed / Double(group.count))     // 折算为秒/章

            // 落库 & 进度（同章多块共用同一份摘要）
            for item in group {
                if Task.isCancelled { break }
                inTotal += item.text.count / 2
                let micro = groupSummary[item.chapter] ?? SourceMicroSummarizer.MicroSummary()
                outTotal += microChars(micro)
                SourceScanCache.mark(profile: pid, idx: item.pos, status: "done",
                                     payload: microPayload(micro),
                                     tokensIn: inTotal, tokensOut: outTotal)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.doneChunks = min(self.doneChunks + 1, self.totalChunks)
                    self.tokensIn = inTotal
                    self.tokensOut = outTotal
                }
                micros.append(micro)
            }
            updateEstimate()
            pos = g
        }
        guard !Task.isCancelled else {
            endBackgroundTask()
            progress.finish()
            return
        }

        // ---- Reduce 一段：按批 40 条归并为阶段摘要（网络失败重试 3 次） ----
        await MainActor.run { [weak self] in self?.phase = .reducing }
        let batchSize = 40
        var stageSummaries: [String] = SourceScanCache.loadReduceStrings(profile: pid)
        for batchStart in stride(from: 0, to: micros.count, by: batchSize) {
            if Task.isCancelled { break }
            let slice = Array(micros[batchStart..<min(batchStart + batchSize, micros.count)])
            let prompt = SourceReducer.batchPrompt(micros: slice, batchChars: 12000)
            let msgs = [LLMMessage(role: .user, content: prompt)]
            let (reply, drained) = await fetchWithRetry(msgs, client: client, config: reduceConfig)
            guard drained else {
                await MainActor.run { [weak self] in self?.cancel() }
                return
            }
            let seq = stageSummaries.count
            stageSummaries.append(reply)
            SourceScanCache.saveReduce(profile: pid, seq: seq, text: reply)
            await MainActor.run { [weak self] in
                self?.stageSummaries = stageSummaries
            }
        }
        guard !Task.isCancelled else {
            endBackgroundTask()
            progress.finish()
            return
        }
        outTotal += stageSummaries.reduce(0) { $0 + $1.count } / 2

        // ---- Reduce 二段：终归并（普通）/ 深度归并（续写：人物快照+伏笔+剧情弧）----
        let analyzedChapters = (chunks.map(\.chapterIndex).max() ?? -1) + 1
        let finalMSGS = isContinuation
            ? SourceReducer.continuationPrompt(stageSummaries: stageSummaries, upToChapter: analyzedChapters)
            : SourceReducer.finalPrompt(stageSummaries: stageSummaries, characters: [])
        let (finalRaw, drained) = await fetchWithRetry(finalMSGS, client: client, config: finalConfig)
        guard drained else {
            await MainActor.run { [weak self] in self?.cancel() }
            return
        }
        guard !Task.isCancelled else {
            endBackgroundTask()
            progress.finish()
            return
        }
        outTotal += finalRaw.count / 2

        guard let profile = isContinuation
            ? try? SourceReducer.parseContinuation(finalRaw, fallbackTitle: sourceTitle, upToChapter: analyzedChapters)
            : try? SourceReducer.parseFinal(finalRaw, fallbackTitle: sourceTitle) else {
            await MainActor.run { [weak self] in
                self?.phase = .failed(isContinuation
                    ? "深度归并产物解析失败，可稍后重试（阶段摘要已缓存）"
                    : "终归并产物解析失败，可稍后重试（阶段摘要已缓存）")
            }
            progress.finish()
            endBackgroundTask()
            return
        }
        if isContinuation {
            // 1~X 章原文存边车（主库 JSON 全量原子写，不塞多 MB 原文）
            profile.hasSourceText = ContinuationStore.save(text: sourceText, profileID: profile.id)
        }
        profile.meta = ScanMeta(totalChapters: chunks.count, totalChars: sourceChars, scanMode: .fast)
        profile.scanState = .init(stage: .done, totalChunks: chunks.count, doneChunks: chunks.count,
                                  tokensIn: inTotal, tokensOut: outTotal, startedAt: .now)
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.resultProfile = profile
            self.tokensIn = inTotal
            self.tokensOut = outTotal
            self.store.upsertSourceProfile(profile)
            self.phase = .done
        }
        ScanTaskBookmark.delete(profileID: pid)   // 完成：任务书签补上断点入口移除
        endBackgroundTask()
        progress.finish()
    }

    /// 微摘要 JSON 编码（落库 payload，换挡重扫描时可复用）
    private func microPayload(_ micro: SourceMicroSummarizer.MicroSummary) -> String? {
        (try? String(data: JSONEncoder().encode(micro), encoding: .utf8)) ?? nil
    }
}
#endif
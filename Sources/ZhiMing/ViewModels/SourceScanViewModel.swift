#if os(iOS) || os(macOS)
import Foundation
import Combine
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

    private var task: Task<Void, Never>?
    private var client: OpenAICompatibleClient?
    private var config: GenerationConfig?
    private let provider: ProviderConfig
    private let store: AppStore
    private var sourceText = ""
    private var sourceTitle = ""
    private var sourceChars = 0
    private var currentMode: ScanMode = .fast

    init(provider: ProviderConfig, store: AppStore) {
        self.provider = provider
        self.store = store
    }

    var isFailed: Bool { if case .failed = phase { return true }; return false }

    var phaseLabel: String {
        switch phase {
        case .idle: return "准备中"
        case .splitting: return "切章分块中…"
        case .mapping: return "逐块提取中（Map）…"
        case .reducing: return "归并档案中（Reduce）…"
        case .done: return "分析完成"
        case .paused: return "已暂停"
        case .failed(let message): return message
        }
    }

    /// 启动/恢复一次扫描：mode 决定档位；doneIndexes 从 SourceScanCache 恢复
    func start(graphText: String, title: String, mode: ScanMode) {
        guard phase == .idle || phase == .paused || isFailed else { return }
        sourceText = graphText
        sourceTitle = title
        sourceChars = graphText.count
        currentMode = mode

        phase = .splitting
        let chunks = SourceScanChunker.chunks(from: graphText, mode: mode)
        totalChunks = chunks.count
        guard !chunks.isEmpty else { phase = .failed("未能从文本中切出章节，请检查文件内容"); return }

        // 断点键：旧档案沿用（暂停恢复），无则新建
        let pid = profileID ?? UUID()
        profileID = pid

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            phase = .failed("未配置有效的模型接口或 API Key")
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        self.client = client
        let config = GenerationConfig(temperature: 0.4, maxTokens: 3000)
        self.config = config

        let done = SourceScanCache.doneIndexes(profile: pid)
        doneChunks = done.count
        let priorIn = tokensIn
        let priorOut = tokensOut

        phase = .mapping
        progress.begin()
        task = Task { [weak self] in
            await self?.runLoop(chunks: chunks, client: client, config: config,
                                done: done, pid: pid, priorIn: priorIn, priorOut: priorOut)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        progress.finish()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        start(graphText: sourceText, title: sourceTitle, mode: sourceMode)
    }

    func reset() {
        task?.cancel()
        task = nil
        progress.finish()
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

    private func runLoop(chunks: [SourceScanChunker.Chunk], client: OpenAICompatibleClient,
                         config: GenerationConfig, done: Set<Int>, pid: UUID,
                         priorIn: Int, priorOut: Int) async {
        var micros: [SourceMicroSummarizer.MicroSummary] = []
        var inTotal = priorIn
        var outTotal = priorOut

        // ---- Map：逐块（跳过 done） ----
        for (pos, chunk) in chunks.enumerated() where !done.contains(pos) {
            if Task.isCancelled { break }
            let msgs = SourceMicroSummarizer.messages(chunk: chunk.text, chapterMarker: nil)
            var reply = ""
            do {
                for try await event in client.streamChat(messages: msgs, config: config) {
                    progress.handle(event)
                    if case .content(let delta) = event { reply += delta }
                    if Task.isCancelled { break }
                }
            } catch {
                // 网络中断：当前块留在 pending，暂停供用户继续
                await MainActor.run { [weak self] in
                    self?.cancel()
                }
                return
            }
            if Task.isCancelled { break }
            inTotal += msgs.totalContentChars / 2
            outTotal += reply.count / 2

            var micro: SourceMicroSummarizer.MicroSummary
            if let parsed = try? SourceMicroSummarizer.parse(reply) {
                micro = parsed
            } else {
                // 宽松重试一次 → 仍败降级空摘要（不阻塞）
                let retry = try? await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        var r = ""
                        for try await event in client.streamChat(messages: msgs, config: config) {
                            if case .content(let delta) = event { r += delta }
                        }
                        return r
                    }
                    guard let first = try await group.next() else { return "" }
                    group.cancelAll()
                    return first
                }
                if let retry, let parsed = try? SourceMicroSummarizer.parse(retry) {
                    micro = parsed
                } else {
                    micro = SourceMicroSummarizer.MicroSummary()
                }
            }
            SourceScanCache.mark(profile: pid, idx: pos, status: "done",
                                 payload: microPayload(micro),
                                 tokensIn: inTotal, tokensOut: outTotal)
            if Task.isCancelled { break }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.doneChunks = min(self.doneChunks + 1, self.totalChunks)
                self.tokensIn = inTotal
                self.tokensOut = outTotal
            }
            micros.append(micro)
        }
        guard !Task.isCancelled else {
            progress.finish()
            return
        }

        // ---- Reduce 一段：按批 40 条归并为阶段摘要 ----
        await MainActor.run { [weak self] in self?.phase = .reducing }
        let batchSize = 40
        var stageSummaries: [String] = SourceScanCache.loadReduceStrings(profile: pid)
        for batchStart in stride(from: 0, to: micros.count, by: batchSize) {
            if Task.isCancelled { break }
            let slice = Array(micros[batchStart..<min(batchStart + batchSize, micros.count)])
            let prompt = SourceReducer.batchPrompt(micros: slice, batchChars: 12000)
            let msgs = [LLMMessage(role: .user, content: prompt)]
            var reply = ""
            do {
                for try await event in client.streamChat(messages: msgs, config: config) {
                    progress.handle(event)
                    if case .content(let delta) = event { reply += delta }
                    if Task.isCancelled { break }
                }
            } catch {
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
            progress.finish()
            return
        }
        outTotal += stageSummaries.reduce(0) { $0 + $1.count } / 2

        // ---- Reduce 二段：终归并为档案 ----
        let finalMSGS = SourceReducer.finalPrompt(stageSummaries: stageSummaries, characters: [])
        var finalRaw = ""
        do {
            for try await event in client.streamChat(messages: finalMSGS, config: config) {
                progress.handle(event)
                if case .content(let delta) = event { finalRaw += delta }
                if Task.isCancelled { break }
            }
        } catch {
            await MainActor.run { [weak self] in self?.cancel() }
            return
        }
        guard !Task.isCancelled else {
            progress.finish()
            return
        }
        outTotal += finalRaw.count / 2

        guard let profile = try? SourceReducer.parseFinal(finalRaw, fallbackTitle: sourceTitle) else {
            await MainActor.run { [weak self] in
                self?.phase = .failed("终归并产物解析失败，可稍后重试（阶段摘要已缓存）")
            }
            progress.finish()
            return
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
        progress.finish()
    }

    /// 微摘要 JSON 编码（落库 payload，换挡重扫描时可复用）
    private func microPayload(_ micro: SourceMicroSummarizer.MicroSummary) -> String? {
        (try? String(data: JSONEncoder().encode(micro), encoding: .utf8)) ?? nil
    }
}
#endif
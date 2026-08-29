import Foundation
import Combine

/// 大纲辅助（卷纲 / 章细纲）流式生成状态机。
/// 产出为「草稿」：由界面点「采纳」后填入编辑框，再走既有保存链路落盘，
/// 因此不存在直接覆盖字段导致的丢失路径。
/// iOS 15 兼容：ObservableObject + @Published（与 WritingSessionViewModel 同款节流模式）。
@MainActor
final class OutlineAssistViewModel: ObservableObject {
    enum Phase: Equatable { case idle, streaming, done }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var draft = ""
    @Published private(set) var truncatedSections: [String] = []
    /// 细纲完成时从 zm-scene 围栏解析出的场景卡（采纳时同步进编辑区）
    @Published private(set) var extractedSceneCards: [SceneCard]?
    /// 卷纲完成时从 zm-dims 围栏解析出的四维补丁（采纳时按开关写入）
    @Published private(set) var extractedDims: VolumeDimsPatch?
    @Published var errorMessage: String?
    /// 流式过程可视化（等待首Token/深度思考/输出统计）
    let progress = StreamProgressTracker()
    private var streamTask: Task<Void, Never>?
    /// 最近一次请求参数，供「重新生成」复用
    private var lastRequest: (kind: OutlineTarget, instruction: String?)?

    // MARK: 批量细纲（大纲页「批量生成本卷细纲」）

    enum BatchPhase: Equatable { case idle, streaming, done }
    @Published private(set) var batchPhase: BatchPhase = .idle
    @Published private(set) var batchSummary: String?
    private var batchTask: Task<Void, Never>?
    /// 本次批量目标章节（写回用）
    private var batchTargets: [Chapter] = []
    private weak var batchStore: AppStore?
    /// 批量重试参数
    private var lastBatchRequest: (chapters: [Chapter], volume: Volume?, novel: Novel, instruction: String?)?

    func start(kind: OutlineTarget, novel: Novel, provider: ProviderConfig, instruction: String?) {
        guard phase != .streaming else { return }
        lastRequest = (kind, instruction)
        draft = ""
        errorMessage = nil
        truncatedSections = []
        extractedSceneCards = nil
        extractedDims = nil

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }

        let systemID: String
        // R18 语言检测样本：优先附加要求，其次现有大纲/梗概（可为空，detectLanguage 会兜底 zh）
        let sample: String
        switch kind {
        case .volume(let volume):
            systemID = PromptID.volumeOutline
            sample = instruction ?? volume.outline ?? novel.synopsis
        case .chapter(let chapter):
            systemID = PromptID.chapterOutline
            sample = instruction ?? chapter.detailedOutline ?? novel.synopsis
        }
        // R18 增强先算好：注入文本要参与输入预算扣减（v1.7）
        let r18Text: String? = novel.r18Enabled
            ? PromptLibrary.shared.r18Supplement(forInput: sample)
            : nil

        // 动态注入（R18/附加指令）先占用预算，剩余额度才装配上下文（v1.7）
        let budget = PromptTemplates.adjustedInputBudget(
            base: provider.contextBudgetChars,
            injections: r18Text, provider.systemPromptExtra)
        let context = ContextBuilder.buildOutlineContext(target: kind, novel: novel, budgetChars: budget)
        truncatedSections = context.truncatedSections

        var scoped = PromptTemplates.outline(systemID: systemID, context: context, instruction: instruction)
        if let r18 = r18Text {
            scoped = PromptTemplates.applying(providerExtra: r18, to: scoped)
        }
        let messages = PromptTemplates.applying(providerExtra: provider.systemPromptExtra, to: scoped)

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        // 体量护栏：超过告警线需确认后才进入流式状态（v1.7）
        let totalChars = messages.totalContentChars
        Task { @MainActor in
            guard await PromptGuard.authorized(totalChars: totalChars) else {
                truncatedSections = []
                return
            }
            self.beginStreaming(messages: messages, client: client, config: config)
        }
    }

    private func beginStreaming(messages: [LLMMessage],
                                client: OpenAICompatibleClient,
                                config: GenerationConfig) {
        phase = .streaming
        KeepAwake.set(true)
        progress.begin()
        streamTask = Task {
            // 流式节流：delta 先进缓冲，约 100ms 刷新一次发布属性，避免逐字重渲染卡顿
            var accumulated = ""
            var lastFlush = Date.distantPast
            do {
                for try await event in client.streamChat(messages: messages, config: config) {
                    progress.handle(event)
                    if case .content(let delta) = event {
                        accumulated += delta
                        let now = Date()
                        if now.timeIntervalSince(lastFlush) >= 0.1 {
                            self.draft = accumulated
                            lastFlush = now
                        }
                    }
                }
                self.finalizeDraft(accumulated)
                self.phase = .done
            } catch is CancellationError {
                // 停止：保留已生成的部分作为草稿供采纳
                self.finalizeDraft(accumulated)
                self.phase = accumulated.isEmpty ? .idle : .done
            } catch {
                self.errorMessage = error.localizedDescription
                self.finalizeDraft(accumulated)
                self.phase = accumulated.isEmpty ? .idle : .done
            }
            progress.finish()
            KeepAwake.set(false)
        }
    }

    func regenerate(novel: Novel, provider: ProviderConfig) {
        guard let request = lastRequest else { return }
        start(kind: request.kind, novel: novel, provider: provider, instruction: request.instruction)
    }

    /// 批量生成本卷未写细纲的章节（一次至多 5 章，超出请分批点击）。
    /// 与单章草稿模式不同：这是「直接落盘」——多章结果一次性写回 detailedOutline，
    /// 完成后给出 summary，由界面提示；中途停止/失败会保留已解析部分。
    func startBatchChapters(chapters: [Chapter], volume: Volume?, novel: Novel,
                            provider: ProviderConfig, instruction: String?,
                            store: AppStore) {
        guard batchPhase != .streaming, !chapters.isEmpty else { return }
        lastBatchRequest = (chapters, volume, novel, instruction)
        batchTargets = chapters
        batchStore = store
        batchSummary = nil
        errorMessage = nil

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }

        // R18 语言检测样本：优先附加要求，其次卷纲/梗概
        let sample = instruction ?? volume?.outline ?? novel.synopsis
        let r18Text: String? = novel.r18Enabled
            ? PromptLibrary.shared.r18Supplement(forInput: sample)
            : nil

        let budget = PromptTemplates.adjustedInputBudget(
            base: provider.contextBudgetChars,
            injections: r18Text, provider.systemPromptExtra)

        var system = PromptLibrary.shared.resolvedText(for: PromptID.chapterBatchOutline)
        if let r18 = r18Text, !r18.isEmpty { system += "\n\n" + r18 }
        if let extra = provider.systemPromptExtra, !extra.isEmpty { system += "\n\n" + extra }

        let user = batchUserPrompt(chapters: chapters, volume: volume, novel: novel,
                                   budgetChars: budget, instruction: instruction)
        let messages = [LLMMessage(role: .system, content: system),
                        LLMMessage(role: .user, content: user)]

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        let totalChars = messages.totalContentChars
        Task { @MainActor in
            guard await PromptGuard.authorized(totalChars: totalChars) else { return }
            self.batchPhase = .streaming
            KeepAwake.set(true)
            self.progress.begin()
            self.beginBatchStreaming(messages: messages, client: client, config: config)
        }
    }

    func regenerateBatch(provider: ProviderConfig) {
        guard let r = lastBatchRequest, let store = batchStore else { return }
        startBatchChapters(chapters: r.chapters, volume: r.volume, novel: r.novel,
                           provider: provider, instruction: r.instruction, store: store)
    }

    func stopBatch() {
        batchTask?.cancel()
        batchPhase = .idle
        progress.finish()
        KeepAwake.set(false)
    }

    /// 批量请求的用户侧上下文：梗概/风格/卷纲/章节清单/已完成细纲/后续章节
    private func batchUserPrompt(chapters: [Chapter], volume: Volume?, novel: Novel,
                                 budgetChars: Int, instruction: String?) -> String {
        var lines: [String] = []
        if !novel.synopsis.isEmpty {
            lines.append("【作品梗概】\n\(String(novel.synopsis.prefix(budgetChars / 3)))")
        }
        if let style = novel.styleGuide, !style.isEmpty {
            lines.append("【风格约束】\n\(style)")
        }
        if let volume, let outline = volume.outline, !outline.isEmpty {
            lines.append("【\(volume.name)·卷纲】\n\(outline)")
        }

        // 本卷章节清单：标出本批与已完成
        let batchTitles = Set(chapters.map { $0.title })
        let all = volume?.chapters ?? []
        let catalog = all.map { ch -> String in
            let done = ch.detailedOutline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            var mark = done ? "（已完成）" : "（待生成）"
            if batchTitles.contains(ch.title) { mark = "▶（本批）" }
            return "- \(ch.title) \(mark)\(done ? "：\(ch.detailedOutline!.prefix(40))" : "")"
        }
        if !catalog.isEmpty {
            lines.append("【本卷章节清单】\n" + catalog.joined(separator: "\n"))
        }

        // 已完成细纲（承接）
        let rendered = (volume?.chapters ?? []).filter {
            !($0.detailedOutline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !rendered.isEmpty {
            lines.append("【已完成细纲】\n" + rendered.map { "\($0.title)：\($0.detailedOutline!)" }.joined(separator: "\n"))
        }

        // 后续章节（衔接/防提前剧透）
        var titles: [String] = []
        var seen = false
        for ch in all {
            if batchTitles.contains(ch.title) { seen = true; continue }
            if seen { titles.append(ch.title) }
        }
        if !titles.isEmpty {
            lines.append("【后续章节】\n" + titles.joined(separator: "\n"))
        }

        let list = chapters.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        lines.append("【本批待生成章节】\n\(list)")
        if let extra = instruction?.trimmingCharacters(in: .whitespacesAndNewlines), !extra.isEmpty {
            lines.append("【附加要求】\n\(extra)")
        }
        return lines.joined(separator: "\n\n")
    }

    private func beginBatchStreaming(messages: [LLMMessage],
                                     client: OpenAICompatibleClient,
                                     config: GenerationConfig) {
        batchTask = Task {
            var raw = ""
            do {
                for try await event in client.streamChat(messages: messages, config: config) {
                    progress.handle(event)
                    if case .content(let delta) = event { raw += delta }
                }
                self.settleBatch(raw: raw, cancelled: false)
            } catch is CancellationError {
                self.settleBatch(raw: raw, cancelled: true)
            } catch {
                self.errorMessage = error.localizedDescription
                self.settleBatch(raw: raw, cancelled: true)
            }
            self.progress.finish()
            self.batchPhase = .idle
            KeepAwake.set(false)
        }
    }

    /// 解析批量 JSON 数组并写回对应章节；返回成功写回数
    @discardableResult
    private func settleBatch(raw: String, cancelled: Bool) -> Int {
        guard let arr = LLMJSONParser.decode([BlueprintChapter].self, fromJSONObjectIn: raw) else {
            if !cancelled { errorMessage = "批量细纲解析失败，可点击「重新生成」重试" }
            batchSummary = nil
            return 0
        }
        guard let store = batchStore else { return 0 }
        var applied = 0
        for item in arr {
            let title = item.title?.trimmingCharacters(in: .whitespaces) ?? ""
            guard let chapter = batchTargets.first(where: { $0.title == title }) else { continue }
            let outline = item.detailed_outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !outline.isEmpty else { continue }
            chapter.detailedOutline = outline
            let cards = (item.scene_cards ?? []).map {
                SceneCard(goal: $0.goal ?? "", obstacle: $0.obstacle ?? "", hook: $0.hook ?? "")
            }.filter { !$0.isEmpty }
            if !cards.isEmpty { chapter.sceneCards = cards }
            applied += 1
        }
        batchSummary = applied > 0
            ? "已生成 \(applied)/\(batchTargets.count) 章细纲" + (cancelled ? "（已停止，保留部分结果）" : "")
            : nil
        store.save()
        return applied
    }

    func stop() { streamTask?.cancel() }

    func reset() {
        draft = ""
        errorMessage = nil
        truncatedSections = []
        extractedSceneCards = nil
        extractedDims = nil
        phase = .idle
        progress.finish()
        KeepAwake.set(false)
    }

    /// 完成时剥离结构化围栏：正文进 draft，场景卡/四维挂到对应提取结果
    /// （解析失败自动降级为纯文字草稿，不影响既有采纳流程）
    private func finalizeDraft(_ raw: String) {
        switch lastRequest?.kind {
        case .chapter:
            let (cards, cleaned) = OutlineDraftParser.extractSceneCards(in: raw)
            extractedSceneCards = cards
            draft = cleaned
        case .volume:
            let (dims, cleaned) = OutlineDraftParser.extractVolumeDims(in: raw)
            extractedDims = dims
            draft = cleaned
        case nil:
            draft = raw
        }
    }
}

// MARK: - 结构化草稿解析

/// 卷四维补丁（zm-dims 围栏）：情绪走向 / 冲突阶梯 / 信息差，字段均可省略；
/// apply 时冲突阶梯按给出顺序重编 level（1 起），空字段跳过，返回应用摘要行。
struct VolumeDimsPatch: Codable {
    struct RungDTO: Codable {
        var obstacle: String
        var turning_point: String?
    }
    struct GapDTO: Codable {
        var start: String?
        var end: String?
    }

    var emotion_arc: [String]?
    var conflict_ladder: [RungDTO]?
    var info_gap: GapDTO?

    var hasContent: Bool {
        !(emotion_arc ?? []).isEmpty || !(conflict_ladder ?? []).isEmpty || info_gap != nil
    }

    /// 写入卷四维；只覆盖本次给出的维度，其余保持不变
    func apply(to volume: Volume) -> [String] {
        var lines: [String] = []

        if let arc = emotion_arc?.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }),
           !arc.isEmpty {
            volume.emotionArc = arc
            lines.append("✅ 情绪走向 ×\(arc.count) 拍")
        }

        if let dtos = conflict_ladder {
            let valid = dtos.filter { !$0.obstacle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !valid.isEmpty {
                volume.conflictLadder = valid.enumerated().map { index, dto in
                    let tp = dto.turning_point?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return ConflictRung(level: index + 1,
                                        obstacle: dto.obstacle.trimmingCharacters(in: .whitespacesAndNewlines),
                                        turningPoint: (tp?.isEmpty == false) ? tp : nil)
                }
                lines.append("✅ 冲突阶梯 ×\(valid.count) 层")
            }
        }

        if let gap = info_gap {
            let start = gap.start?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let end = gap.end?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !start.isEmpty || !end.isEmpty {
                volume.infoGap = InfoGap(start: start, end: end)
                lines.append("✅ 信息差已更新")
            }
        }

        return lines
    }
}

/// 大纲草稿尾部结构化围栏解析（与写作助手补丁同思路）：扫描 ``` 围栏，
/// 跳过语言标记行后能解码为目标类型的首个块即命中。
enum OutlineDraftParser {

    static func extractSceneCards(in text: String) -> (cards: [SceneCard]?, cleanedText: String) {
        guard let hit = firstFence(in: text, decode: decodeSceneCards) else { return (nil, text) }
        return (hit.value, cleaned(text, removing: hit.range))
    }

    static func extractVolumeDims(in text: String) -> (dims: VolumeDimsPatch?, cleanedText: String) {
        guard let hit = firstFence(in: text, decode: decodeDims) else { return (nil, text) }
        return (hit.value, cleaned(text, removing: hit.range))
    }

    private static func firstFence<T>(in text: String, decode: (String) -> T?) -> (value: T, range: Range<String.Index>)? {
        var cursor = text.startIndex
        while let open = text.range(of: "```", range: cursor..<text.endIndex) {
            guard let close = text.range(of: "```", range: open.upperBound..<text.endIndex) else { return nil }
            let inner = text[open.upperBound..<close.lowerBound]
            let payload: Substring
            if let newline = inner.firstIndex(of: "\n") {
                payload = inner[inner.index(after: newline)...]
            } else {
                payload = inner
            }
            if let value = decode(String(payload)) {
                return (value, open.lowerBound..<close.upperBound)
            }
            cursor = close.upperBound
        }
        return nil
    }

    private static func cleaned(_ text: String, removing range: Range<String.Index>) -> String {
        var result = text
        result.replaceSubrange(range, with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeSceneCards(_ source: String) -> [SceneCard]? {
        guard let data = source.data(using: .utf8),
              let cards = try? JSONDecoder().decode([SceneCard].self, from: data) else { return nil }
        let meaningful = cards.filter { !$0.isEmpty }
        return meaningful.isEmpty ? nil : meaningful
    }

    private static func decodeDims(_ source: String) -> VolumeDimsPatch? {
        guard let data = source.data(using: .utf8),
              let dims = try? JSONDecoder().decode(VolumeDimsPatch.self, from: data),
              dims.hasContent else { return nil }
        return dims
    }
}

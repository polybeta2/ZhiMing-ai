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

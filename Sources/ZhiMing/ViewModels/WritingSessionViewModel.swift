#if os(iOS) || os(macOS)
import Foundation
import Combine
import ZhiMingCore

/// AI 写作会话：流式草稿状态机（续写 / 改写）
/// iOS 15 兼容：ObservableObject + @Published
@MainActor
final class WritingSessionViewModel: ObservableObject {
    enum Phase: Equatable { case idle, streaming, done }
    enum Mode { case writing(wordTarget: Int), continueWriting(wordTarget: Int), rewrite(mode: String, selection: String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var draft = ""
    @Published private(set) var truncatedSections: [String] = []
    @Published var errorMessage: String?
    /// 流式过程可视化（等待首Token/深度思考/输出统计）
    let progress = StreamProgressTracker()
    private var streamTask: Task<Void, Never>?

    func start(mode: Mode, chapter: Chapter, novel: Novel, provider: ProviderConfig, instruction: String?) {
        guard phase != .streaming else { return }
        draft = ""
        errorMessage = nil
        truncatedSections = []

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        // R18 增强先算好：注入文本要参与输入预算扣减（v1.7）
        let r18Text: String?
        if novel.r18Enabled {
            // 按输入语言注入对应版本的虚构情色写作规范（语言二选一，不混注）
            let sample = (instruction?.isEmpty == false) ? instruction! : String(chapter.content.prefix(400))
            r18Text = PromptLibrary.shared.r18Supplement(forInput: sample)
        } else {
            r18Text = nil
        }

        let baseMessages: [LLMMessage]
        switch mode {
        case .writing(let wordTarget):
            // 从零撰写整章：content 为空时正文末尾段自然为空，上下文装配与续写共用
            let budget = PromptTemplates.adjustedInputBudget(
                base: provider.contextBudgetChars,
                injections: r18Text, provider.systemPromptExtra)
            let context = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: budget)
            truncatedSections = context.truncatedSections
            baseMessages = PromptTemplates.writing(context: context, wordTarget: wordTarget, extra: instruction)
        case .continueWriting(let wordTarget):
            // 动态注入（R18/附加指令）先占用预算，剩余额度才装配上下文
            let budget = PromptTemplates.adjustedInputBudget(
                base: provider.contextBudgetChars,
                injections: r18Text, provider.systemPromptExtra)
            let context = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: budget)
            truncatedSections = context.truncatedSections
            baseMessages = PromptTemplates.continueWriting(context: context, wordTarget: wordTarget, extra: instruction)
            // 注：不得把上下文写入日志——正文/细纲/摘要均属用户隐私（验收用的 print 已移除）
        case .rewrite(let rewriteMode, let selection):
            baseMessages = PromptTemplates.rewrite(mode: rewriteMode, selection: selection, instruction: instruction)
        }
        var scoped = baseMessages
        if let r18 = r18Text {
            scoped = PromptTemplates.applying(providerExtra: r18, to: scoped)
        }
        let messages = PromptTemplates.applying(providerExtra: provider.systemPromptExtra, to: scoped)

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
        KeepAwake.set(true)   // 生成中保持屏幕常亮
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
                self.draft = accumulated
                self.phase = .done
            } catch is CancellationError {
                self.draft = accumulated
                self.phase = accumulated.isEmpty ? .idle : .done
            } catch {
                self.errorMessage = error.localizedDescription
                self.phase = accumulated.isEmpty ? .idle : .done
            }
            progress.finish()
            KeepAwake.set(false)
        }
    }

    func stop() { streamTask?.cancel() }

    /// 采纳续写草稿：先打 ai_insert 快照再追加正文
    func accept(into chapter: Chapter) {
        SnapshotService.snapshot(chapter, trigger: "ai_insert")
        chapter.content += draft
        chapter.wordCount = chapter.content.count
        chapter.updatedAt = .now
        reset()
    }

    /// 采纳改写草稿：先打 ai_insert 快照再替换选中片段
    func acceptReplacing(in chapter: Chapter, selection: String) {
        SnapshotService.snapshot(chapter, trigger: "ai_insert")
        if let range = chapter.content.range(of: selection) {
            chapter.content.replaceSubrange(range, with: draft)
        } else {
            chapter.content += draft
        }
        chapter.wordCount = chapter.content.count
        chapter.updatedAt = .now
        reset()
    }

    func reset() {
        draft = ""
        errorMessage = nil
        truncatedSections = []
        phase = .idle
        progress.finish()
        KeepAwake.set(false)
    }
}
#endif

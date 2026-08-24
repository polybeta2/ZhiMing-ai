import Foundation
import Combine

/// AI 写作会话：流式草稿状态机（续写 / 改写）
/// iOS 15 兼容：ObservableObject + @Published
@MainActor
final class WritingSessionViewModel: ObservableObject {
    enum Phase: Equatable { case idle, streaming, done }
    enum Mode { case continueWriting(wordTarget: Int), rewrite(mode: String, selection: String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var draft = ""
    @Published private(set) var truncatedSections: [String] = []
    @Published var errorMessage: String?
    private var streamTask: Task<Void, Never>?

    func start(mode: Mode, chapter: Chapter, novel: Novel, provider: ProviderConfig, instruction: String?) {
        guard phase != .streaming else { return }
        draft = ""
        errorMessage = nil
        truncatedSections = []
        phase = .streaming
        KeepAwake.set(true)   // 生成中保持屏幕常亮

        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            phase = .idle
            KeepAwake.set(false)
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        let messages: [LLMMessage]
        switch mode {
        case .continueWriting(let wordTarget):
            let context = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: provider.contextBudgetChars)
            truncatedSections = context.truncatedSections
            messages = PromptTemplates.continueWriting(context: context, wordTarget: wordTarget, extra: instruction)
            // 验收用：控制台可核对上下文是否包含风格约束/细纲/前文摘要
            print("[ContextBuilder] 续写上下文（\(context.rendered.count) 字）：\n\(context.rendered)")
            if !context.truncatedSections.isEmpty {
                print("[ContextBuilder] 超预算被裁剪：\(context.truncatedSections.joined(separator: "、"))")
            }
        case .rewrite(let rewriteMode, let selection):
            messages = PromptTemplates.rewrite(mode: rewriteMode, selection: selection, instruction: instruction)
        }

        streamTask = Task {
            do {
                for try await delta in client.streamChat(messages: messages, config: config) {
                    self.draft += delta
                }
                self.phase = .done
            } catch is CancellationError {
                self.phase = self.draft.isEmpty ? .idle : .done
            } catch {
                self.errorMessage = error.localizedDescription
                self.phase = self.draft.isEmpty ? .idle : .done
            }
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
        KeepAwake.set(false)
    }
}

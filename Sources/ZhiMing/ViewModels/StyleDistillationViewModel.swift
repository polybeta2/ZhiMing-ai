#if os(iOS) || os(macOS)
import Foundation
import Combine
import ZhiMingCore

/// 蒸馏向导状态机：把 Core 流水线事件映射为 UI 阶段 + 流式进度
@MainActor
final class StyleDistillationViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle, measuring, analyzing, buildingCard, checking, done, failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var result: StyleProfile?
    let progress = StreamProgressTracker()
    private var task: Task<Void, Never>?

    func run(sourceText: String, sourceNote: String, provider: ProviderConfig) {
        guard phase == .idle || isFailed else { return }
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            phase = .failed("未配置有效的模型接口或 API Key")
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: 0.3, maxTokens: provider.maxTokens)
        let library = PromptLibrary.shared
        let service = StyleDistillationService(client: client, config: config)

        phase = .measuring
        progress.begin()
        task = Task { [weak self] in
            do {
                for try await event in service.events(
                    sourceText: sourceText,
                    sourceNote: sourceNote,
                    analyzeSystem: library.resolvedText(for: PromptID.styleDistillAnalyze),
                    cardSystem: library.resolvedText(for: PromptID.styleDistillCard),
                    fixSystem: library.resolvedText(for: PromptID.styleDistillFix)
                ) {
                    switch event {
                    case .phase(let p):
                        self?.apply(p)
                    case .stream(let s):
                        self?.progress.handle(s)
                    case .completed(let profile):
                        self?.result = profile
                    }
                }
                if self?.result != nil { self?.phase = .done }
            } catch is CancellationError {
                self?.phase = .idle
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
            self?.progress.finish()
        }
    }

    var isFailed: Bool { if case .failed = phase { return true }; return false }

    var phaseLabel: String {
        switch phase {
        case .idle: return "准备中"
        case .measuring: return "本地计量中…"
        case .analyzing: return "机制分析中（LLM）…"
        case .buildingCard: return "风格卡汇总中（LLM）…"
        case .checking: return "查重校验中…"
        case .done: return "蒸馏完成"
        case .failed(let message): return message
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
        progress.finish()
    }

    private func apply(_ p: StyleDistillPhase) {
        switch p {
        case .measuring: phase = .measuring
        case .analyzing: phase = .analyzing
        case .buildingCard: phase = .buildingCard
        case .checking: phase = .checking
        }
    }
}
#endif

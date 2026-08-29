#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 风格体检结果页：进入即对草稿做一次单调用体检（对照档案 eval 基准 + 本地快检）。
/// 只报告不修改——修改动作由作者自行采纳或走「去AI味」。
struct StyleEvalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: String
    let draftTitle: String
    let evalCard: String          // StyleCardRenderer.render(profile, variant: .eval)
    let provider: ProviderConfig

    @State private var result: StyleEvalResult?
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?
    @StateObject private var progress = StreamProgressTracker()

    private var localReport: String {
        ProseChecker.reportLines(in: draft).joined(separator: "\n")
    }

    var body: some View {
        CompatNavigationView {
            Group {
                if let result {
                    resultList(result)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Label(errorMessage, systemImage: "xmark.octagon.fill")
                            .foregroundColor(.red)
                        Button("重新体检") { run() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        StreamingStatusView(tracker: progress)
                        Text("体检中…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("风格体检")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("重新体检") { run() }
                        .disabled(result == nil && errorMessage == nil)
                }
            }
        }
        .onAppear { if result == nil && errorMessage == nil { run() } }
        .onDisappear { task?.cancel() }
    }

    // MARK: 结果列表

    private func resultList(_ result: StyleEvalResult) -> some View {
        Form {
            Section("总评") {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(result.overall ?? 0)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("/ 10")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            Section("七维得分") {
                ForEach(Array((result.scores ?? []).enumerated()), id: \.offset) { _, score in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(score.dimension ?? "未知维度").font(.subheadline)
                            Spacer()
                            Text("\(score.score ?? 0)")
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundColor((score.score ?? 0) >= 7 ? .green : (score.score ?? 0) >= 5 ? .orange : .red)
                        }
                        if let note = score.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let drifts = result.drifts, !drifts.isEmpty {
                listSection("风格漂移", drifts)
            }
            if let aiFlavor = result.ai_flavor, !aiFlavor.isEmpty {
                listSection("AI 腔", aiFlavor)
            }
            if let moves = result.moves, !moves.isEmpty {
                listSection("修改动作", moves)
            }
            if !localReport.isEmpty {
                Section("本地快检（程序统计）") {
                    Text(localReport)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func listSection(_ title: String, _ items: [String]) -> some View {
        Section(title) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item).font(.footnote)
            }
        }
    }

    // MARK: 执行

    private func run() {
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }
        result = nil
        errorMessage = nil
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: 0.2, maxTokens: provider.maxTokens)
        let evaluator = StyleEvaluator(client: client, config: config)
        let system = MainActor.assumeIsolated {
            PromptLibrary.shared.resolvedText(for: PromptID.styleEval)
        }
        progress.begin()
        task?.cancel()
        task = Task {
            do {
                let value = try await evaluator.evaluate(
                    draft: draft, draftTitle: draftTitle,
                    localReport: localReport.isEmpty ? nil : localReport,
                    evalSystem: system, evalCard: evalCard)
                if !Task.isCancelled { self.result = value }
            } catch is CancellationError {
                // 忽略取消
            } catch {
                if !Task.isCancelled { self.errorMessage = error.localizedDescription }
            }
            progress.finish()
        }
    }
}
#endif

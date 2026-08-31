#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 风格体检结果页：进入即对草稿做一次单调用体检（对照档案 eval 基准 + 本地快检）。
/// 只报告不修改——修改动作由作者自行采纳或走「去AI味」。
/// v2.12.4 起支持「一键应用修改」：按体检结果（漂移/AI腔/修改动作）AI 改写全文，
/// 内联预览后确认自动写回（写回前由调用方建版本快照）。
struct StyleEvalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: String
    let draftTitle: String
    let evalCard: String          // StyleCardRenderer.render(profile, variant: .eval)
    let provider: ProviderConfig
    /// 确认应用修改后的正文（nil = 不启用一键应用）
    var onApply: ((String) -> Void)? = nil

    @State private var result: StyleEvalResult?
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?
    @StateObject private var progress = StreamProgressTracker()

    /// 一键应用：改写中 / 改写产物 / 改写错误
    @State private var replacing = false
    @State private var appliedDraft: String?
    @State private var replaceError: String?
    @State private var replaceTask: Task<Void, Never>?
    @StateObject private var replaceProgress = StreamProgressTracker()

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
        .onDisappear {
            task?.cancel()
            replaceTask?.cancel()
        }
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
            if onApply != nil {
                Section {
                    applySection(result)
                }
            }
        }
    }

    // MARK: 一键应用修改（确认后自动写回）

    @ViewBuilder
    private func applySection(_ result: StyleEvalResult) -> some View {
        if let applied = appliedDraft {
            // 改写产物预览：对比字数 + 内联确认
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("改写结果")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(draft.count) → \(applied.count) 字")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(draft.count == applied.count ? "" : (applied.count > draft.count ? "+\(applied.count - draft.count)" : "\(applied.count - draft.count)"))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(applied.count >= draft.count ? .secondary : .orange)
                }
                Text(applied)
                    .font(.footnote)
                    .lineLimit(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("重新生成") { runReplace() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("取消") { appliedDraft = nil }
                        .buttonStyle(.bordered)
                    Button("确认替换") {
                        onApply?(applied)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if replacing {
            VStack(alignment: .leading, spacing: 8) {
                StreamingStatusView(tracker: replaceProgress)
                Text("正在按体检结果改写全文…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("把「风格漂移 / AI 腔 / 修改动作」交给 AI 一次性改写到正文（仅修复列出的问题，其余保持原样）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let replaceError {
                    Label(replaceError, systemImage: "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Button {
                    runReplace()
                } label: {
                    Label("一键应用修改（AI 改写全文）", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(replacing)
            }
        }
    }

    /// 按体检结果改写全文：流式生成修正版正文（只修复问题，其余不动）
    private func runReplace() {
        guard let onApply else { return }
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            replaceError = "未配置有效的模型接口或 API Key"
            return
        }
        appliedDraft = nil
        replaceError = nil
        replacing = true

        let issues = [
            result?.drifts?.isEmpty == false ? "【风格漂移】\n" + result!.drifts!.joined(separator: "\n") : nil,
            result?.ai_flavor?.isEmpty == false ? "【AI 腔】\n" + result!.ai_flavor!.joined(separator: "\n") : nil,
            result?.moves?.isEmpty == false ? "【修改动作】\n" + result!.moves!.joined(separator: "\n") : nil,
        ].compactMap { $0 }.joined(separator: "\n\n")
        let system = """
        你是一次性文风修正器。根据给出的【体检问题】修正下面的正文：1) 只修复列出的风格漂移、\
        AI 腔与修改动作问题，改得自然不留痕迹；2) 情节、人物、结构、篇幅、设定一律保持原样，\
        不得增删剧情；3) 直接输出修正后的完整正文，不要任何标题、说明或额外格式。
        """
        let user = "【体检问题】\n\(issues)\n\n【正文】\n\(draft)"

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: 0.35, maxTokens: provider.maxTokens)
        replaceProgress.begin()
        replaceTask?.cancel()
        replaceTask = Task {
            var out = ""
            do {
                for try await event in client.streamChat(messages: [
                    LLMMessage(role: .system, content: system),
                    LLMMessage(role: .user, content: user),
                ], config: config) {
                    replaceProgress.handle(event)
                    if case .content(let delta) = event { out += delta }
                    if Task.isCancelled { break }
                }
                if !Task.isCancelled, !out.isEmpty {
                    appliedDraft = out
                } else if !Task.isCancelled {
                    replaceError = "改写结果为空，请重试"
                }
            } catch {
                if !Task.isCancelled { replaceError = error.localizedDescription }
            }
            replaceProgress.finish()
            if !Task.isCancelled { replacing = false }
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

import SwiftUI
import UIKit

/// 章节编辑器：沉浸编辑 + 底部 AI 工具条（续写 / 改写 / 润色 / 摘要 / 版本）
/// 续写字数快捷选项 800/1500/2500；草稿经 DraftCard 采纳/重新生成/放弃
struct ChapterEditorView: View {
    @EnvironmentObject private var store: AppStore
    let chapter: Chapter

    @StateObject private var vm = WritingSessionViewModel()
    @State private var text: String
    @State private var saveTask: Task<Void, Never>?
    @State private var showContinueSheet = false
    @State private var showRewriteSheet = false
    @State private var rewritePresetMode = "改写"
    @State private var showNoProviderAlert = false
    @State private var showSettings = false
    @State private var showSnapshots = false

    // 会话内模型切换（仅当前编辑器生效）
    @State private var sessionProvider: ProviderConfig?
    @State private var showModelSelector = false

    // 摘要（叙事账本）
    @State private var summaryGenerating = false
    @State private var summaryError: String?
    @State private var showSummarySheet = false
    @State private var lastSummaryRaw = ""
    @State private var summaryTask: Task<Void, Never>?

    // 记录最近一次生成参数，供「重新生成」复用
    @State private var lastContinue: (wordTarget: Int, instruction: String?)?
    @State private var lastRewrite: (mode: String, selection: String, instruction: String?)?

    init(chapter: Chapter) {
        self.chapter = chapter
        _text = State(initialValue: chapter.content)
    }

    private var novel: Novel? { chapter.volume?.novel }

    /// 会话内选择的模型优先，否则用全局默认提供商
    private var activeProvider: ProviderConfig? { sessionProvider ?? store.defaultProvider }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(chapter.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: AppTheme.spacing[1])
                Text("\(text.count) 字")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            }
            .padding(.horizontal, AppTheme.spacing[3])
            .padding(.vertical, AppTheme.spacing[1])

            TextEditor(text: $text)
                .font(.body)
                .padding(.horizontal, AppTheme.spacing[2])

            if vm.phase != .idle {
                DraftCard(
                    vm: vm,
                    isRewrite: lastRewrite != nil && lastContinue == nil,
                    onAccept: acceptDraft,
                    onRegenerate: regenerate,
                    onDiscard: { vm.reset() }
                )
                .padding(.bottom, AppTheme.spacing[1])
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                if summaryGenerating {
                    HStack {
                        ProgressView()
                        Text("正在生成章节摘要…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.spacing[3])
                    .padding(.vertical, AppTheme.spacing[1])
                }
                if let summaryError {
                    Label(summaryError, systemImage: "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, AppTheme.spacing[3])
                }
                aiToolbar
            }
        }
        .animation(AppTheme.Spring.standard, value: vm.phase)
        .navigationTitle("编辑")
        .navigationBarTitleDisplayMode(.inline)
        .zmOnChange(of: text) { newValue in
            chapter.content = newValue          // 轻量同步正文
            scheduleSave()                      // 防抖保存：字数与落盘不逐键执行
        }
        // 快照回退等外部改动同步回编辑器
        .zmOnChange(of: chapter.content) { newValue in
            if newValue != text { text = newValue }
        }
        .onDisappear {
            saveTask?.cancel()
            summaryTask?.cancel()
            vm.stop()
            saveNow()
        }
        .sheet(isPresented: $showContinueSheet) {
            ContinueWritingSheet { wordTarget, instruction in
                startContinue(wordTarget: wordTarget, instruction: instruction)
            }
        }
        .sheet(isPresented: $showRewriteSheet) {
            RewriteSheet(presetMode: rewritePresetMode) { mode, selection, instruction in
                startRewrite(mode: mode, selection: selection, instruction: instruction)
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            SummaryEditSheet(chapter: chapter, rawFallback: lastSummaryRaw) {
                lastSummaryRaw = ""
                generateSummary()
            }
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorSheet(selection: $sessionProvider)
        }
        .alert("尚未配置模型提供商", isPresented: $showNoProviderAlert) {
            Button("去设置") { showSettings = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先在「设置 → 模型提供商」中添加并测试一个 OpenAI 兼容接口。")
        }
        .background(hiddenLink(destination: SettingsView(), isActive: $showSettings))
        .background(hiddenLink(destination: SnapshotListView(chapter: chapter), isActive: $showSnapshots))
    }

    /// iOS 15：隐藏 NavigationLink 替代 navigationDestination(isPresented:)
    private func hiddenLink<Destination: View>(destination: Destination, isActive: Binding<Bool>) -> some View {
        NavigationLink(destination: destination, isActive: isActive) { EmptyView() }
            .hidden()
    }

    // MARK: - 工具条

    private var aiToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacing[1]) {
                // 会话内模型切换（Kelivo 同款胶囊）
                Button {
                    showModelSelector = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(activeProvider?.modelName ?? "未配置")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 84)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.zmPress)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())

                toolButton("续写", icon: "text.badge.plus") {
                    guard ensureProvider() else { return }
                    showContinueSheet = true
                }
                toolButton("改写", icon: "pencil.and.outline") {
                    guard ensureProvider() else { return }
                    rewritePresetMode = "改写"
                    showRewriteSheet = true
                }
                toolButton("润色", icon: "wand.and.stars") {
                    guard ensureProvider() else { return }
                    rewritePresetMode = "润色"
                    showRewriteSheet = true
                }
                toolButton("去AI味", icon: "text.badge.checkmark") {
                    guard ensureProvider() else { return }
                    rewritePresetMode = "去AI味"
                    showRewriteSheet = true
                }
                toolButton(chapter.summary == nil ? "生成摘要" : "摘要", icon: "doc.plaintext") {
                    if chapter.summary != nil {
                        summaryError = nil
                        showSummarySheet = true
                    } else {
                        generateSummary()
                    }
                }
                toolButton("版本", icon: "clock.arrow.circlepath") {
                    showSnapshots = true
                }
            }
            .padding(.horizontal, AppTheme.spacing[2])
            .padding(.vertical, AppTheme.spacing[1])
        }
        .background(.bar)
    }

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .padding(.horizontal, AppTheme.spacing[2])
                .padding(.vertical, 7)
        }
        .buttonStyle(.zmPress)
        .background(
            Capsule()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            Capsule().strokeBorder(Color(uiColor: .separator).opacity(0.25), lineWidth: 0.5)
        )
    }

    private func ensureProvider() -> Bool {
        if activeProvider == nil {
            showNoProviderAlert = true
            return false
        }
        return true
    }

    // MARK: - 生成流程

    private func startContinue(wordTarget: Int, instruction: String?) {
        guard let provider = activeProvider, let novel else { return }
        lastContinue = (wordTarget, instruction)
        lastRewrite = nil
        vm.start(
            mode: .continueWriting(wordTarget: wordTarget),
            chapter: chapter,
            novel: novel,
            provider: provider,
            instruction: instruction
        )
    }

    private func startRewrite(mode: String, selection: String, instruction: String?) {
        guard let provider = activeProvider, let novel else { return }
        // 「去AI味」：先跑本地文风快检，把问题清单并入要求（模型按清单优先处理）
        var effectiveInstruction = instruction
        if mode == "去AI味" {
            let issues = ProseChecker.reportLines(in: selection)
            let report = issues.isEmpty
                ? "本地快检未发现明显模板腔，请通读后按规范微调。"
                : issues.joined(separator: "\n")
            effectiveInstruction = "【本地体检结果】\n\(report)" +
                (instruction.map { "\n【作者附加】\($0)" } ?? "")
        }
        lastRewrite = (mode, selection, instruction)
        lastContinue = nil
        vm.start(
            mode: .rewrite(mode: mode, selection: selection),
            chapter: chapter,
            novel: novel,
            provider: provider,
            instruction: effectiveInstruction
        )
    }

    private func regenerate() {
        if let last = lastContinue {
            startContinue(wordTarget: last.wordTarget, instruction: last.instruction)
        } else if let last = lastRewrite {
            startRewrite(mode: last.mode, selection: last.selection, instruction: last.instruction)
        }
    }

    private func acceptDraft() {
        ZMHaptics.success()
        if let last = lastRewrite {
            vm.acceptReplacing(in: chapter, selection: last.selection)
        } else {
            vm.accept(into: chapter)
        }
        text = chapter.content
        lastContinue = nil
        lastRewrite = nil
        saveNow()
    }

    // MARK: - 摘要（叙事账本简化版）

    private func generateSummary() {
        guard let provider = activeProvider else {
            showNoProviderAlert = true
            return
        }
        guard !chapter.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryError = "本章还没有正文，先写内容再生成摘要"
            return
        }
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            summaryError = "默认提供商缺少有效的 Base URL 或 API Key"
            return
        }

        summaryGenerating = true
        summaryError = nil
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: 0.2, maxTokens: provider.maxTokens)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.summarize(content: chapter.content, title: chapter.title)
        )

        // 体量护栏（v1.7）：整章正文无预算直发，超告警线先确认
        let totalChars = messages.totalContentChars
        summaryTask?.cancel()
        summaryTask = Task { @MainActor in
            guard await PromptGuard.authorized(totalChars: totalChars) else {
                summaryGenerating = false
                return
            }
            var raw = ""
            do {
                for try await delta in client.streamChat(messages: messages, config: config) {
                    raw += delta
                }
                if !Task.isCancelled { applySummaryResult(raw) }
            } catch is CancellationError {
                // 忽略取消
            } catch {
                if !Task.isCancelled { summaryError = error.localizedDescription }
            }
            if !Task.isCancelled { summaryGenerating = false }
        }
    }

    /// 解析成功 → 写入 chapter.summary；失败 → 打开编辑页展示原始输出供手动修正
    private func applySummaryResult(_ raw: String) {
        if let result = LLMJSONParser.decode(LLMJSONParser.SummaryResult.self, fromJSONObjectIn: raw) {
            let summary: ChapterSummary
            if let existing = chapter.summary {
                summary = existing
            } else {
                summary = ChapterSummary(summaryText: result.summary)
                summary.chapter = chapter
                chapter.summary = summary
            }
            summary.summaryText = result.summary
            summary.keyFacts = result.key_facts ?? []
            store.save()
        } else {
            summaryError = "摘要 JSON 解析失败，请手动修正"
            lastSummaryRaw = raw
            showSummarySheet = true
        }
    }

    // MARK: - 保存

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        chapter.content = text
        chapter.wordCount = text.count
        chapter.updatedAt = .now
        store.save()
    }
}

// MARK: - 续写参数 Sheet

private struct ContinueWritingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wordTarget = 1500
    @State private var instruction = ""
    let onStart: (Int, String?) -> Void

    private let options = [800, 1500, 2500]

    var body: some View {
        CompatNavigationView {
            Form {
                Section("续写字数") {
                    Picker("目标字数", selection: $wordTarget) {
                        ForEach(options, id: \.self) { option in
                            Text("约 \(option) 字").tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("附加指令（可选）") {
                    MultilineField(text: $instruction, placeholder: "例如：本段以对话推进，减少环境描写…", minHeight: 56)
                }
            }
            .navigationTitle("AI 续写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始生成") {
                        let extra = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                        onStart(wordTarget, extra.isEmpty ? nil : extra)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 改写/润色/扩写 Sheet

private struct RewriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: String
    @State private var selection = ""
    @State private var instruction = ""
    let onStart: (String, String, String?) -> Void

    private let modes = ["改写", "润色", "扩写", "去AI味"]

    init(presetMode: String, onStart: @escaping (String, String, String?) -> Void) {
        _mode = State(initialValue: presetMode)
        self.onStart = onStart
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("操作") {
                    Picker("模式", selection: $mode) {
                        ForEach(modes, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    MultilineField(text: $selection, placeholder: "选中要处理的片段，粘贴到这里…", minHeight: 120)
                    Button {
                        if let copied = UIPasteboard.general.string, !copied.isEmpty {
                            selection = copied
                        }
                    } label: {
                        Label("从剪贴板粘贴选中的文字", systemImage: "doc.on.clipboard")
                    }
                    // 不在 body 渲染期读取 UIPasteboard：会反复触发系统粘贴授权横幅
                } header: {
                    Text("待处理片段")
                } footer: {
                    Text("在正文中长按选中目标段落并复制，再粘贴到此处。采纳后原文中的该片段将被替换。")
                }
                Section("附加要求（可选）") {
                    MultilineField(text: $instruction, placeholder: "例如：加强动作描写，压缩对话…", minHeight: 48)
                }
            }
            .navigationTitle(mode == "去AI味" ? "去 AI 味" : "AI \(mode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始生成") {
                        let extra = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                        onStart(mode, selection, extra.isEmpty ? nil : extra)
                        dismiss()
                    }
                    .disabled(selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - 摘要编辑页（可手动修改 summaryText 与 keyFacts；解析失败时可粘贴修正）

private struct SummaryEditSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter
    var onRegenerate: () -> Void

    @State private var summaryText: String
    @State private var keyFacts: [String]
    @State private var newFact = ""

    init(chapter: Chapter, rawFallback: String = "", onRegenerate: @escaping () -> Void) {
        self.chapter = chapter
        self.onRegenerate = onRegenerate
        _summaryText = State(initialValue: chapter.summary?.summaryText ?? rawFallback)
        _keyFacts = State(initialValue: chapter.summary?.keyFacts ?? [])
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("本章摘要") {
                    MultilineField(text: $summaryText, placeholder: "120-200 字，覆盖主要事件与人物动向…", minHeight: 110)
                }
                Section {
                    ForEach(Array(keyFacts.enumerated()), id: \.offset) { index, fact in
                        HStack {
                            Text(fact)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                keyFacts.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("添加关键事实（不可逆的设定变化）", text: $newFact)
                            .onSubmit { addFact() }
                        Button("添加") { addFact() }
                            .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("关键事实")
                } footer: {
                    Text("下一章续写时自动回注最近 3 章的摘要与关键事实。")
                }
                Section {
                    Button {
                        dismiss()
                        onRegenerate()
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                    }
                    if chapter.summary != nil {
                        Button(role: .destructive) {
                            chapter.summary = nil
                            store.save()
                            dismiss()
                        } label: {
                            Label("删除摘要", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("章节档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func addFact() {
        let value = newFact.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        keyFacts.append(value)
        newFact = ""
    }

    private func save() {
        let trimmed = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let summary: ChapterSummary
        if let existing = chapter.summary {
            summary = existing
        } else {
            summary = ChapterSummary(summaryText: trimmed)
            summary.chapter = chapter
            chapter.summary = summary
        }
        summary.summaryText = trimmed
        summary.keyFacts = keyFacts
        store.save()
        dismiss()
    }
}

import SwiftUI
import UIKit

/// 章节编辑器：沉浸编辑 + 底部 AI 工具条（续写 / 改写 / 润色）
/// 续写字数快捷选项 800/1500/2500；草稿经 DraftCard 采纳/重新生成/放弃
struct ChapterEditorView: View {
    @Environment(AppStore.self) private var store
    let chapter: Chapter

    @State private var vm = WritingSessionViewModel()
    @State private var text: String
    @State private var saveTask: Task<Void, Never>?
    @State private var showContinueSheet = false
    @State private var showRewriteSheet = false
    @State private var rewritePresetMode = "改写"
    @State private var showNoProviderAlert = false
    @State private var showSettings = false
    @State private var showSnapshots = false

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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(chapter.title)
                    .font(.headline)
                Spacer()
                Text("\(text.count) 字")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.spacing[3])
            .padding(.vertical, AppTheme.spacing[1])

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
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
            } else {
                if summaryGenerating {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("正在生成章节摘要…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.spacing[3])
                    .padding(.vertical, AppTheme.spacing[1])
                }
                if let summaryError {
                    Label(summaryError, systemImage: "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, AppTheme.spacing[3])
                }
                aiToolbar
            }
        }
        .navigationTitle("编辑")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: text) { _, newValue in
            chapter.content = newValue          // 轻量同步正文
            scheduleSave()                      // 防抖保存：字数与落盘不逐键执行
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
                // 重新生成
                lastSummaryRaw = ""
                generateSummary()
            }
        }
        .alert("尚未配置模型提供商", isPresented: $showNoProviderAlert) {
            Button("去设置") { showSettings = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先在「设置 → 模型提供商」中添加并测试一个 OpenAI 兼容接口。")
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showSnapshots) {
            SnapshotListView(chapter: chapter)
        }
        // 快照回退等外部改动同步回编辑器
        .onChange(of: chapter.content) { _, newValue in
            if newValue != text { text = newValue }
        }
    }

    // MARK: - 工具条

    private var aiToolbar: some View {
        HStack(spacing: 0) {
            toolButton("续写", icon: "text.badge.plus") {
                guard ensureProvider() else { return }
                showContinueSheet = true
            }
            toolButton("改写", icon: "text.replace") {
                guard ensureProvider() else { return }
                rewritePresetMode = "改写"
                showRewriteSheet = true
            }
            toolButton("润色", icon: "wand.and.stars") {
                guard ensureProvider() else { return }
                rewritePresetMode = "润色"
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
        .background(.bar)
    }

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacing[1])
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, AppTheme.spacing[0])
    }

    private func ensureProvider() -> Bool {
        if store.defaultProvider == nil {
            showNoProviderAlert = true
            return false
        }
        return true
    }

    // MARK: - 生成流程

    private func startContinue(wordTarget: Int, instruction: String?) {
        guard let provider = store.defaultProvider, let novel else { return }
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
        guard let provider = store.defaultProvider, let novel else { return }
        lastRewrite = (mode, selection, instruction)
        lastContinue = nil
        vm.start(
            mode: .rewrite(mode: mode, selection: selection),
            chapter: chapter,
            novel: novel,
            provider: provider,
            instruction: instruction
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
        guard let provider = store.defaultProvider else {
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
        let messages = PromptTemplates.summarize(content: chapter.content, title: chapter.title)

        summaryTask?.cancel()
        summaryTask = Task { @MainActor in
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
            try? await Task.sleep(for: .milliseconds(800))
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
        NavigationStack {
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
                    TextField("例如：本段以对话推进，减少环境描写…", text: $instruction, axis: .vertical)
                        .lineLimit(2...4)
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
        .presentationDetents([.medium])
    }
}

// MARK: - 改写/润色/扩写 Sheet

private struct RewriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: String
    @State private var selection = ""
    @State private var instruction = ""
    let onStart: (String, String, String?) -> Void

    private let modes = ["改写", "润色", "扩写"]

    init(presetMode: String, onStart: @escaping (String, String, String?) -> Void) {
        _mode = State(initialValue: presetMode)
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
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
                    TextField("选中要处理的片段，粘贴到这里…", text: $selection, axis: .vertical)
                        .lineLimit(6...14)
                    Button {
                        if let copied = UIPasteboard.general.string, !copied.isEmpty {
                            selection = copied
                        }
                    } label: {
                        Label("从剪贴板粘贴选中的文字", systemImage: "doc.on.clipboard")
                    }
                    .disabled(UIPasteboard.general.string?.isEmpty != false)
                } header: {
                    Text("待处理片段")
                } footer: {
                    Text("在正文中长按选中目标段落并复制，再粘贴到此处。采纳后原文中的该片段将被替换。")
                }
                Section("附加要求（可选）") {
                    TextField("例如：加强动作描写，压缩对话…", text: $instruction, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle("AI \(mode)")
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
        .presentationDetents([.large])
    }
}

// MARK: - 摘要编辑页（可手动修改 summaryText 与 keyFacts；解析失败时可粘贴修正）

private struct SummaryEditSheet: View {
    @Environment(AppStore.self) private var store
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
        NavigationStack {
            Form {
                Section("本章摘要") {
                    TextField("120-200 字，覆盖主要事件与人物动向…", text: $summaryText, axis: .vertical)
                        .lineLimit(6...16)
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

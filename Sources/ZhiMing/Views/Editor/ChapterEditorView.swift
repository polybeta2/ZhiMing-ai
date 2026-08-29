#if canImport(SwiftUI)
import SwiftUI
import UIKit
import ZhiMingCore

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
    /// 会话内文风档案三态：跟随书籍绑定 / 临时关闭 / 临时指定（不落库）
    enum SessionStyle: Equatable {
        case followBook, off, custom(UUID)
    }
    @State private var sessionStyle: SessionStyle = .followBook
    @State private var showStylePicker = false
    @State private var showEvalSheet = false
    @State private var showEvalNeedsText = false
    /// 进入页面时的默认提供商快照：避免 body 直接读 store 而订阅全局刷新——
    /// 每次防抖保存都会触达全局 objectWillChange，长文编辑时会把编辑器整树重算，造成卡顿
    @State private var cachedDefaultProvider: ProviderConfig?

    // 摘要（叙事账本）
    @State private var summaryGenerating = false
    @State private var summaryError: String?
    @State private var showSummarySheet = false
    @State private var lastSummaryRaw = ""
    @State private var summaryTask: Task<Void, Never>?
    @StateObject private var summaryProgress = StreamProgressTracker()

    // 记录最近一次生成参数，供「重新生成」复用
    @State private var lastContinue: (isNewChapter: Bool, wordTarget: Int, instruction: String?)?
    @State private var lastRewrite: (mode: String, selection: String, instruction: String?)?

    init(chapter: Chapter) {
        self.chapter = chapter
        _text = State(initialValue: chapter.content)
    }

    private var novel: Novel? { chapter.volume?.novel }

    /// 会话内选择的模型优先，否则用进入页面时的全局默认提供商快照
    private var activeProvider: ProviderConfig? { sessionProvider ?? cachedDefaultProvider }

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
                    HStack(spacing: AppTheme.spacing[2]) {
                        StreamingStatusView(tracker: summaryProgress)
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
        .onAppear {
            // 进入页面即快照默认提供商；编辑器不再订阅 store 全局刷新（长文编辑卡顿修复）
            if cachedDefaultProvider == nil { cachedDefaultProvider = store.defaultProvider }
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
            ContinueWritingSheet(isNewChapter: text.count == 0, hasOutline: chapter.detailedOutline?.isEmpty == false) { wordTarget, instruction in
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
        .sheet(isPresented: $showStylePicker) {
            SessionStylePickerSheet(selection: $sessionStyle, novel: novel)
        }
        .sheet(isPresented: $showEvalSheet) {
            if let provider = activeProvider {
                StyleEvalSheet(
                    draft: text,
                    draftTitle: chapter.title,
                    evalCard: styleCard(variant: .eval) ?? "（未启用文风档案，仅按通用编辑标准体检）",
                    provider: provider
                )
            }
        }
        .alert("正文太短", isPresented: $showEvalNeedsText) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("风格体检至少需要 60 字正文，先写一点再来。")
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

                // 会话内文风档案切换（三态胶囊，点击弹选择页）
                Button {
                    showStylePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat")
                        Text(sessionStyleLabel)
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

                // 字数为 0 时是「撰写」（从零成章），否则「续写」
                toolButton(text.count == 0 ? "撰写" : "续写", icon: text.count == 0 ? "square.and.pencil" : "text.badge.plus") {
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
                toolButton("体检", icon: "stethoscope") {
                    guard ensureProvider() else { return }
                    guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 60 else {
                        showEvalNeedsText = true
                        return
                    }
                    showEvalSheet = true
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

    // MARK: - 会话内文风档案解析（P1 会话级三态，不落库）

    private var sessionStyleLabel: String {
        switch sessionStyle {
        case .followBook:
            if let novel, let id = novel.activeStyleProfileID,
               let p = store.styleProfiles.first(where: { $0.id == id }) {
                return "文风:\(p.name)"
            }
            return "文风:未绑定"
        case .off: return "文风:关"
        case .custom(let id):
            return store.styleProfiles.first { $0.id == id }.map { "文风:\($0.name)" } ?? "文风:失效"
        }
    }

    /// 按会话三态解析当前生效档案；nil = 本次请求不注入档案卡
    private func resolveSessionProfile() -> StyleProfile? {
        guard let novel else { return nil }
        switch sessionStyle {
        case .followBook:
            return novel.activeStyleProfile(in: store.styleProfiles)
        case .off:
            return nil
        case .custom(let id):
            return store.styleProfiles.first { $0.id == id }
        }
    }

    private func styleCard(variant: StyleCardVariant) -> String? {
        guard let profile = resolveSessionProfile() else { return nil }
        let card = StyleCardRenderer.render(profile, variant: variant)
        return card.isEmpty ? nil : card
    }

    // MARK: - 生成流程

    private func startContinue(wordTarget: Int, instruction: String?) {
        guard let provider = activeProvider, let novel else { return }
        let isNewChapter = text.count == 0
        lastContinue = (isNewChapter, wordTarget, instruction)
        lastRewrite = nil
        vm.start(
            mode: isNewChapter ? .writing(wordTarget: wordTarget) : .continueWriting(wordTarget: wordTarget),
            chapter: chapter,
            novel: novel,
            provider: provider,
            instruction: instruction,
            styleCard: styleCard(variant: .writing)
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
            instruction: effectiveInstruction,
            styleCard: styleCard(variant: mode == "去AI味" ? .antiAI : .writing)
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
            summaryProgress.begin()
            do {
                for try await event in client.streamChat(messages: messages, config: config) {
                    summaryProgress.handle(event)
                    if case .content(let delta) = event { raw += delta }
                }
                if !Task.isCancelled { applySummaryResult(raw) }
            } catch is CancellationError {
                // 忽略取消
            } catch {
                if !Task.isCancelled { summaryError = error.localizedDescription }
            }
            summaryProgress.finish()
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
            applyForeshadowExtractions(from: result)
            store.save()
        } else {
            summaryError = "摘要 JSON 解析失败，请手动修正"
            lastSummaryRaw = raw
            showSummarySheet = true
        }
    }

    /// 提取伏笔静默落库：追加 open 伏笔 + 标记 suggestedResolved
    private func applyForeshadowExtractions(from result: LLMJSONParser.SummaryResult) {
        // 1) new_foreshadowings 静默追加 open 伏笔（埋设位置=当前章；单次至多 10 条，字段超限前缀截断）
        guard let novel = chapter.volume?.novel else { return }
        let volumeIndex = novel.sortedVolumes.firstIndex(where: { $0.id == chapter.volume?.id }).map { $0 + 1 }
        let chapterOrder = chapter.sortOrder
        for extraction in (result.new_foreshadowings ?? []).prefix(10) {
            let title = (extraction.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            novel.foreshadowings.append(Foreshadowing(
                title: String(title.prefix(PromptLimits.foreshadowTextFieldCap)),
                detail: (extraction.detail ?? "").isEmpty ? nil : String(extraction.detail!.prefix(PromptLimits.foreshadowTextFieldCap)),
                plantedVolumeIndex: volumeIndex,
                plantedChapterOrder: chapterOrder,
                plannedResolve: (extraction.planned_resolve ?? "").isEmpty ? nil : String(extraction.planned_resolve!.prefix(PromptLimits.foreshadowTextFieldCap))
            ))
        }
        // 2) resolved_foreshadowing_titles 匹配既有 open 伏笔并标 suggestedResolved=true（至多 5 条，不翻转 status）
        var matched = 0
        for candidate in (result.resolved_foreshadowing_titles ?? []) where matched < 5 {
            let target = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { continue }
            if let index = novel.foreshadowings.firstIndex(where: { $0.status == .open && ($0.title.contains(target) || target.contains($0.title)) }) {
                novel.foreshadowings[index].suggestedResolved = true
                matched += 1
            }
        }
    }

    // MARK: - 保存

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            // 1.2s 防抖：减少全量 library.json 编码与全局刷新的频率（长文编辑卡顿优化）
            try? await Task.sleep(nanoseconds: 1_200_000_000)
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

// MARK: - 撰写/续写参数 Sheet

private struct ContinueWritingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wordTarget: Int
    @State private var instruction = ""
    let isNewChapter: Bool
    var hasOutline: Bool = true
    let onStart: (Int, String?) -> Void

    /// 撰写：1500~4500 步进 500；续写：快捷 800/1500/2500
    private let newChapterOptions = Array(stride(from: 1500, through: 4500, by: 500))
    private let continueOptions = [800, 1500, 2500]

    init(isNewChapter: Bool, hasOutline: Bool = true, onStart: @escaping (Int, String?) -> Void) {
        self.isNewChapter = isNewChapter
        self.hasOutline = hasOutline
        self.onStart = onStart
        _wordTarget = State(initialValue: isNewChapter ? 2000 : 1500)
    }

    var body: some View {
        CompatNavigationView {
            Form {
                if isNewChapter && !hasOutline {
                    Section {
                        Label("本章还没有细纲，撰写质量会大打折扣。建议先到「大纲」页生成本章细纲。", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                Section(isNewChapter ? "撰写字数" : "续写字数") {
                    if isNewChapter {
                        // 7 档放不下 segmented，用默认 menu 样式
                        Picker("目标字数", selection: $wordTarget) {
                            ForEach(newChapterOptions, id: \.self) { option in
                                Text("约 \(option) 字").tag(option)
                            }
                        }
                    } else {
                        Picker("目标字数", selection: $wordTarget) {
                            ForEach(continueOptions, id: \.self) { option in
                                Text("约 \(option) 字").tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("附加指令（可选）") {
                    MultilineField(text: $instruction, placeholder: isNewChapter
                        ? "例如：开篇以对话切入，节奏快一些…"
                        : "例如：本段以对话推进，减少环境描写…", minHeight: 56)
                }
            }
            .navigationTitle(isNewChapter ? "AI 撰写" : "AI 续写")
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
#endif

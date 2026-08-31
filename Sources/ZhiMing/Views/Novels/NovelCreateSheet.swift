#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 新建作品：空白建书 / 一句话立项 两个入口
struct NovelCreateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 创建成功回调（传入新作品 id，由首页负责跳转）
    var onCreated: (UUID) -> Void = { _ in }

    private enum Mode { case choose, blank, oneLine, fullIdea }
    @State private var mode: Mode = .choose

    // 同人立项：档案选择
    @State private var showFanficPicker = false
    @State private var showContinuation = false
    /// 已选档案 → 弹文风选择（sheet item）
    @State private var styleChoiceProfile: StyleChoiceJob?

    // 空白建书表单
    @State private var title = ""
    @State private var synopsis = ""
    @State private var perspective = ""
    @State private var styleGuide = ""
    @State private var accentIndex = 0

    // 一句话立项
    @State private var brief = ""

    // 完整思路立项
    @State private var fullIdeaTitle = ""
    @State private var fullIdeaText = ""
    /// 已启用的示例标签 id（保存到作品，生成蓝图时按关键词命中注入）
    @State private var selectedTagIDs: Set<String> = []
    @State private var previewTag: PromptTag?
    @ObservedObject private var library = PromptLibrary.shared

    // R18 增强（两种建书方式共用；开启需首次确认免责说明，内联卡片确认）
    @State private var r18Enabled = false
    @AppStorage("r18.notice.confirmed.v1") private var r18NoticeConfirmed = false
    @State private var showR18Notice = false

    private let perspectiveOptions = ["", "第一人称", "第三人称限知", "第三人称全知", "多视角交替"]

    var body: some View {
        CompatNavigationView {
            Group {
                switch mode {
                case .choose: chooseView
                case .blank: blankForm
                case .oneLine: oneLineView
                case .fullIdea: fullIdeaView
                }
            }
            .navigationTitle(titleForMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var titleForMode: String {
        switch mode {
        case .choose: return "新建作品"
        case .blank: return "空白建书"
        case .oneLine: return "一句话立项"
        case .fullIdea: return "完整思路立项"
        }
    }

    // MARK: - 入口选择

    private var chooseView: some View {
        VStack(spacing: AppTheme.spacing[3]) {
            entryCard(
                icon: "book.closed",
                title: "空白建书",
                subtitle: "自己填写书名、梗概与风格，从零开始搭建"
            ) {
                mode = .blank
            }
            entryCard(
                icon: "wand.and.stars",
                title: "一句话立项",
                subtitle: "说出你的创意，AI 生成主题、角色、世界观与卷纲蓝图"
            ) {
                mode = .oneLine
            }
            entryCard(
                icon: "doc.text.magnifyingglass",
                title: "完整思路立项",
                subtitle: "已有完整设定或大纲，跳过问答直接规划卷章结构"
            ) {
                mode = .fullIdea
            }
            entryCard(
                icon: "books.vertical",
                title: "同人立项",
                subtitle: "选择一本原作档案，围绕其人物与事件创作不 OOC 的同人"
            ) {
                showFanficPicker = true
            }
            entryCard(
                icon: "square.and.pencil",
                title: "续写小说",
                subtitle: "导入断更/未写完的小说，选一章开始，AI 无缝续写"
            ) {
                showContinuation = true
            }
            if store.sourceProfiles.isEmpty {
                Text("还没有原作档案：先到书库页「原作档案库」导入 txt 分析。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AppTheme.spacing[3])
        .sheet(isPresented: $showFanficPicker) { fanficProfilePicker }
        .sheet(item: $styleChoiceProfile) { job in
            FanficStyleChoiceSheet(profile: job.profile, store: store) { styleID in
                styleChoiceProfile = nil
                createFromSource(job.profile, styleProfileID: styleID)
            }
        }
        .sheet(isPresented: $showContinuation) {
            ContinuationImportSheet { profile in
                createContinuationFromSource(profile)
            }
        }
    }

    private func entryCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacing[2]) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacing[3])
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 同人立项

    /// 已选档案 + 文风选择（sheet identity）
    private struct StyleChoiceJob: Identifiable {
        let id = UUID()
        let profile: SourceNovelProfile
    }

    /// 档案选择列表：未完成分析的档案置灰并引导完成扫描
    private var fanficProfilePicker: some View {
        CompatNavigationView {
            Group {
                if store.sourceProfiles.isEmpty {
                    EmptyStateView(title: "还没有原作档案", systemImage: "books.vertical",
                                   description: "先到书库页「原作档案库」导入一本 txt 小说完成分析，才能以它为地基创作同人。")
                        .padding()
                } else {
                    List {
                        ForEach(store.sourceProfiles) { profile in
                            Button {
                                styleChoiceProfile = StyleChoiceJob(profile: profile)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(profile.title).font(.headline)
                                        Text("\(profile.meta.totalChapters) 章 · 人物 \(profile.characters.count) · 事件 \(profile.timeline.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if profile.scanState.isComplete {
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Text("分析未完成")
                                            .font(.caption2.bold())
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!profile.scanState.isComplete)
                            .opacity(profile.scanState.isComplete ? 1 : 0.55)
                        }
                    }
                }
            }
            .navigationTitle("选择原作档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("取消") { showFanficPicker = false }
                }
            }
        }
    }

    /// 从原作档案建同人书：绑定 sourceProfileID；文风按用户在建档时的选择设置
    private func createFromSource(_ profile: SourceNovelProfile, styleProfileID: UUID?) {
        let novel = Novel(title: "《\(profile.title)》同人", synopsis: "")
        novel.sourceProfileID = profile.id
        // 文风：继承档案绑定 / 不启用 / 其他档案，由用户在建档时选定
        novel.activeStyleProfileID = styleProfileID
        novel.accentColorHex = AppTheme.accentPresets[0].hexString

        let volume = Volume(name: "第一卷", sortOrder: 1)
        volume.novel = novel
        novel.volumes.append(volume)

        // 立项会话：从澄清开始（会先确认同人遵守度：严格原作线/IF 线/仅借设定）
        let thread = ChatThread(purpose: "creation")
        thread.novel = novel
        novel.chatThreads.append(thread)

        store.novels.append(novel)
        store.save()
        showFanficPicker = false
        dismiss()
        onCreated(novel.id)
    }

    // MARK: - 续写建书

    /// 从续写档案建书：绑定档案 + skipsClarification 直达结构规划（复用完整思路立项机制）。
    /// 续写档案额外导入：原作 1~X 章只读章节、角色卡、世界观、未回收伏笔台账。
    private func createContinuationFromSource(_ profile: SourceNovelProfile) {
        let upTo = profile.continuationFromChapter
        let novel = Novel(title: "《\(profile.title)》续写", synopsis: "")
        novel.sourceProfileID = profile.id
        // 续写默认继承原作文风档案（若已绑定）
        novel.activeStyleProfileID = profile.styleProfileID
        novel.accentColorHex = AppTheme.accentPresets[0].hexString

        // 原作卷：续写档案带边车原文 → 导入 1~X 章为只读章节（正文锚定与衔接用）
        if let upTo, profile.hasSourceText,
           let source = ContinuationStore.load(profileID: profile.id) {
            let originalVolume = Volume(name: "原作（\(upTo) 章）", sortOrder: 1)
            originalVolume.novel = novel
            novel.volumes.append(originalVolume)
            for (i, chapter) in StyleChapterSampler.split(source).prefix(upTo).enumerated() {
                let ch = Chapter(title: chapter.marker, sortOrder: i + 1)
                ch.volume = originalVolume
                ch.content = chapter.body
                ch.wordCount = chapter.body.count
                ch.isOriginal = true
                originalVolume.chapters.append(ch)
            }
        }

        let volume = Volume(name: "第一卷", sortOrder: novel.volumes.count + 1)
        volume.novel = novel
        novel.volumes.append(volume)

        // 角色卡：CanonCharacter → CharacterCard（现状快照进 physicalState）
        for canon in profile.characters {
            let card = CharacterCard(name: canon.name)
            card.aliases = canon.aliases
            card.appearance = canon.appearance
            card.personality = canon.personality
            card.background = [canon.oneLine, canon.abilities].compactMap { $0 }.filter { !$0.isEmpty }
                .joined(separator: "；")
            card.physicalState = canon.currentState
            novel.characters.append(card)
        }
        // 世界观：CanonWorldEntry → WorldEntry（自由分类映射到固定五类）
        for world in profile.worldbuilding {
            let entry = WorldEntry(category: Self.mappedWorldCategory(world.category), name: world.name, content: world.content)
            entry.novel = novel
            novel.worldEntries.append(entry)
        }
        // 未回收伏笔 → 伏笔台账（status=open，planted 章号按原作卷第 1 卷计）
        for thread in profile.openThreads {
            novel.foreshadowings.append(Foreshadowing(
                title: thread.title, detail: thread.detail,
                plantedVolumeIndex: thread.plantedChapter.map { _ in 1 },
                plantedChapterOrder: thread.plantedChapter,
                status: .open))
        }

        let thread = ChatThread(purpose: "creation")
        thread.novel = novel
        novel.chatThreads.append(thread)
        // 进入对话即自动规划续写蓝图（ChatView 的 skipsClarification 路径）
        thread.skipsClarification = true
        if let upTo {
            novel.synopsis = """
            续写《\(profile.title)》：已分析原作前 \(upTo) 章。请基于注入的原作上下文（人物现状、未回收伏笔、剧情弧、世界设定、近期原文）规划续写蓝图：\
            1) 续写方向与分卷结构；2) 未回收伏笔的回收计划（各伏笔回收的大致位置）；\
            3) 基调与文风衔接（延续近期原文笔感）；4) 从第 \(upTo + 1) 章开始续写。
            """
        } else {
            // 从档案库加载的同人精度档案（无截止章号）：按全书时间窗续写
            novel.synopsis = """
            续写《\(profile.title)》（同人精度档案，基于全书时间窗）。请基于注入的原作上下文规划续写蓝图：\
            1) 续写方向与分卷结构；2) 基调与文风衔接；3) 从原作结局之后继续。
            """
        }

        store.novels.append(novel)
        store.save()
        dismiss()
        onCreated(novel.id)
    }

    /// 原作档案自由分类 → App 固定五类（含关键词启发，未命中归「其他」）
    private static func mappedWorldCategory(_ raw: String) -> String {
        switch raw {
        case let s where s.contains("地点") || s.contains("场景"): return "地点"
        case let s where s.contains("势力") || s.contains("组织") || s.contains("阵营"): return "势力"
        case let s where s.contains("规则") || s.contains("体系") || s.contains("设定"): return "规则"
        case let s where s.contains("物品") || s.contains("道具") || s.contains("装备"): return "物品"
        default: return "其他"
        }
    }

    // MARK: - 空白建书

    private var blankForm: some View {
        Form {
            Section("基本信息") {
                TextField("书名", text: $title)
                MultilineField(text: $synopsis, placeholder: "一句话梗概（可选）", fixedHeight: 100)
            }
            Section("叙事") {
                Picker("叙事视角", selection: $perspective) {
                    ForEach(perspectiveOptions, id: \.self) { option in
                        Text(option.isEmpty ? "未指定" : option).tag(option)
                    }
                }
                MultilineField(text: $styleGuide, placeholder: "风格约束（可选，续写时注入）", fixedHeight: 80)
            }
            Section("强调色") {
                HStack(spacing: AppTheme.spacing[2]) {
                    ForEach(AppTheme.accentPresets.indices, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.accentPresets[index])
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .opacity(accentIndex == index ? 1 : 0)
                            )
                            .onTapGesture { accentIndex = index }
                    }
                    Spacer()
                }
                .padding(.vertical, AppTheme.spacing[0])
                .disabled(r18Enabled)
                if r18Enabled {
                    Text("已启用 R18：本作品强调色锁定为血红色")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            Section("成人内容") {
                Toggle(isOn: r18Binding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R18 增强（虚构情色写作辅助）")
                        Text("开启后写作与立项自动注入对应语言的 R18 写作规范；强调色强制血红色并标注 R18 Enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if showR18Notice {
                    r18ConfirmCard()
                }
            }
            Section {
                Button("创建作品") { createBlank() }
                    .frame(maxWidth: .infinity)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func createBlank() {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let novel = Novel(title: name, synopsis: synopsis.trimmingCharacters(in: .whitespaces))
        novel.perspective = perspective.isEmpty ? nil : perspective
        novel.styleGuide = styleGuide.isEmpty ? nil : styleGuide.trimmingCharacters(in: .whitespaces)
        // R18 开启时强调色强制血红色，忽略用户所选
        novel.accentColorHex = r18Enabled ? Novel.r18AccentHex : AppTheme.accentPresets[accentIndex].hexString
        novel.r18Enabled = r18Enabled

        let volume = Volume(name: "第一卷", sortOrder: 1)
        volume.novel = novel
        novel.volumes.append(volume)

        store.novels.append(novel)
        store.save()
        onCreated(novel.id)
    }

    // MARK: - 完整思路立项

    /// 已有完整思路：跳过澄清问答，进入对话直接规划卷章结构
    private var fullIdeaView: some View {
        VStack(spacing: AppTheme.spacing[2]) {
            Text("粘贴你的完整思路（世界观、人物、核心冲突、关键情节、结局方向），AI 将跳过问答直接规划卷章结构。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("书名（可选，留空取思路开头）", text: $fullIdeaTitle)
                .padding(AppTheme.spacing[2])
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

            MultilineField(
                text: $fullIdeaText,
                placeholder: "在此粘贴完整思路：\n· 世界观与背景设定\n· 主要人物与关系\n· 核心冲突与主线走向\n· 关键情节节点（如男女主初遇、重大转折）\n· 结局方向…",
                fixedHeight: 220
            )
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))

            // R18 开关 + 内联确认（与其他建书方式共用）
            VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                Toggle(isOn: r18Binding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R18 增强（虚构情色写作辅助）").font(.subheadline)
                        Text(r18Enabled ? "已开启：注入本地打包的 R18 写作规范（按语言二选一），强调色锁定血红" : "为本书开启成人向写作规范注入")
                            .font(.caption2)
                            .foregroundStyle(r18Enabled ? Color.red : .secondary)
                    }
                }
                if showR18Notice {
                    r18ConfirmCard()
                }
            }

            Button {
                createFromFullIdea()
            } label: {
                Label("开始立项", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing[1])
            }
            .buttonStyle(.borderedProminent)
            .disabled(fullIdeaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.spacing[3])
    }

    private func createFromFullIdea() {
        let text = fullIdeaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let name = fullIdeaTitle.trimmingCharacters(in: .whitespaces)
        let displayTitle = !name.isEmpty ? name
            : (text.count <= 14 ? text : String(text.prefix(14)) + "…")
        let novel = Novel(title: displayTitle, synopsis: text)
        novel.accentColorHex = r18Enabled ? Novel.r18AccentHex : AppTheme.accentPresets[0].hexString
        novel.r18Enabled = r18Enabled

        // 完整思路立项：标记跳过澄清，ChatView 进入时直接规划卷章结构
        let thread = ChatThread(purpose: "creation")
        thread.skipsClarification = true
        thread.novel = novel
        novel.chatThreads.append(thread)

        store.novels.append(novel)
        store.save()
        onCreated(novel.id)
    }

    // MARK: - 一句话立项

    private var oneLineView: some View {
        VStack(spacing: AppTheme.spacing[2]) {
            Text("用一句话描述你的故事创意，AI 将生成可编辑的作品蓝图。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            MultilineField(
                text: $brief,
                placeholder: "例如：失忆的灯塔看守人收到一封写给自己的讣告…",
                minHeight: 96
            )
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))

            tagLibrarySection

            // R18 开关 + 内联确认（一句话立项）
            VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                Toggle(isOn: r18Binding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R18 增强（虚构情色写作辅助）").font(.subheadline)
                        Text(r18Enabled ? "已开启：注入本地打包的 R18 写作规范（按语言二选一），强调色锁定血红" : "为本书开启成人向写作规范注入")
                            .font(.caption2)
                            .foregroundStyle(r18Enabled ? Color.red : .secondary)
                    }
                }
                if showR18Notice {
                    r18ConfirmCard()
                }
            }

            Button {
                createFromBrief()
            } label: {
                Label("开始立项", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing[1])
            }
            .buttonStyle(.borderedProminent)
            .disabled(brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.spacing[3])
        .sheet(item: $previewTag) { tag in
            TagPreviewSheet(
                tag: tag,
                isEnabled: Binding(
                    get: { selectedTagIDs.contains(tag.id) },
                    set: { if $0 { selectedTagIDs.insert(tag.id) } else { selectedTagIDs.remove(tag.id) } }
                )
            )
        }
    }

    // MARK: 示例标签库（点击预览 → 开关启用）

    private var tagLibrarySection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
                ForEach(library.tagCategories) { category in
                    Text(category.name)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacing[1]) {
                            ForEach(category.tags) { tag in
                                tagChip(tag)
                            }
                        }
                    }
                }
                Text("点击标签预览完整内容；打开「启用」后，只有当你的创意中包含该标签的关键词时才会注入对应指导。未启用的标签永不注入。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: 210)
    }

    // MARK: R18 内联确认（不用系统弹窗：部分系统版本 alert 按钮动作不可靠）

    /// 开关联动：未确认过时第一次打开开关只展开内联警示，不真正开启
    private var r18Binding: Binding<Bool> {
        Binding(
            get: { r18Enabled },
            set: { newValue in
                if newValue && !r18NoticeConfirmed {
                    withAnimation { showR18Notice = true }
                } else {
                    r18Enabled = newValue
                    if !newValue { withAnimation { showR18Notice = false } }
                }
            }
        )
    }

    /// 空白表单 / 一句话立项 共用的确认卡
    private func r18ConfirmCard() -> some View {
        InlineConfirmCard(
            title: "启用 R18 增强？",
            message: Novel.r18NoticeText,
            confirmLabel: "同意并开启",
            onConfirm: {
                r18NoticeConfirmed = true
                withAnimation {
                    r18Enabled = true
                    showR18Notice = false
                }
            },
            onCancel: { withAnimation { showR18Notice = false } }
        )
    }

    private func tagChip(_ tag: PromptTag) -> some View {
        let selected = selectedTagIDs.contains(tag.id)
        return Button {
            previewTag = tag
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                Text(tag.name).font(.footnote)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                selected ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func createFromBrief() {
        let text = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let displayTitle = text.count <= 14 ? text : String(text.prefix(14)) + "…"
        let novel = Novel(title: displayTitle, synopsis: text)
        // R18 开启时强调色强制血红色
        novel.accentColorHex = r18Enabled ? Novel.r18AccentHex : AppTheme.accentPresets[0].hexString
        novel.r18Enabled = r18Enabled
        novel.enabledTagIDs = Array(selectedTagIDs)   // 智能注入依据（ChatView 生成蓝图时读取）

        // 立项会话线程（Phase 8 状态机将读取 synopsis 作为初始创意）
        let thread = ChatThread(purpose: "creation")
        thread.novel = novel
        novel.chatThreads.append(thread)

        store.novels.append(novel)
        store.save()
        onCreated(novel.id)
    }
}

/// 标签预览：完整预设内容 + 启用开关
private struct TagPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tag: PromptTag
    @Binding var isEnabled: Bool

    var body: some View {
        CompatNavigationView {
            Form {
                Section("标签") {
                    Toggle(isOn: $isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tag.name).font(.headline)
                            Text(isEnabled ? "已启用（命中关键词时注入）" : "未启用")
                                .font(.caption)
                                .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                        }
                    }
                    Text("触发关键词：" + tag.keywords.joined(separator: "、"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("预设提示词内容") {
                    ScrollView {
                        Text(tag.presetText)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 200)
                }
            }
            .navigationTitle("提示词预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
// MARK: - 同人文风选择（继承档案 / 不启用 / 其他文风档案）

/// 同人建书时的文风选择项
private enum FanficStyleChoice: Equatable {
    case inherit          // 继承档案绑定的文风
    case none             // 不启用任何文风
    case custom(UUID)     // 指定其他小说的文风档案
}

/// 选择文风 sheet：默认跟随档案绑定（有绑定则预选），可改为不启用或选用其他文风档案
private struct FanficStyleChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: SourceNovelProfile
    let store: AppStore
    var onConfirm: (UUID?) -> Void

    @State private var choice: FanficStyleChoice

    init(profile: SourceNovelProfile, store: AppStore, onConfirm: @escaping (UUID?) -> Void) {
        self.profile = profile
        self.store = store
        self.onConfirm = onConfirm
        _choice = State(initialValue: profile.styleProfileID != nil ? .inherit : .none)
    }

    private var boundName: String? {
        profile.styleProfileID.flatMap { id in
            store.styleProfiles.first { $0.id == id }?.name
        }
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section(footer: Text("选择用哪种文风来写这本同人；书创建后仍可在「设定 → 文风档案」中随时换绑。")) {
                    if let name = boundName {
                        row("继承原作文风（\(name)）", choice: .inherit)
                    }
                    row("不启用任何文风", choice: .none)
                    if !store.styleProfiles.isEmpty {
                        ForEach(store.styleProfiles) { style in
                            row("文风：\(style.name)", choice: .custom(style.id))
                        }
                    }
                }
            }
            .navigationTitle("选择文风")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始创作") { confirm() }
                }
            }
        }
    }

    private func row(_ label: String, choice: FanficStyleChoice) -> some View {
        Button {
            self.choice = choice
        } label: {
            HStack {
                Text(label)
                Spacer()
                if self.choice == choice {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func confirm() {
        let styleID: UUID? = {
            switch choice {
            case .inherit: return profile.styleProfileID
            case .none: return nil
            case .custom(let id): return id
            }
        }()
        onConfirm(styleID)
        dismiss()
    }
}
#endif

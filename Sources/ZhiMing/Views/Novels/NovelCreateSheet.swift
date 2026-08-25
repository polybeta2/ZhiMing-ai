import SwiftUI

/// 新建作品：空白建书 / 一句话立项 两个入口
struct NovelCreateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 创建成功回调（传入新作品 id，由首页负责跳转）
    var onCreated: (UUID) -> Void = { _ in }

    private enum Mode { case choose, blank, oneLine }
    @State private var mode: Mode = .choose

    // 空白建书表单
    @State private var title = ""
    @State private var synopsis = ""
    @State private var perspective = ""
    @State private var styleGuide = ""
    @State private var accentIndex = 0

    // 一句话立项
    @State private var brief = ""
    /// 已启用的示例标签 id（保存到作品，生成蓝图时按关键词命中注入）
    @State private var selectedTagIDs: Set<String> = []
    @State private var previewTag: PromptTag?
    @ObservedObject private var library = PromptLibrary.shared

    // R18 增强（两种建书方式共用；开启需首次确认免责说明）
    @State private var r18Enabled = false
    @AppStorage("r18.notice.confirmed.v1") private var r18NoticeConfirmed = false
    @State private var showR18Notice = false

    /// 开启时若未确认过免责说明，先弹确认框
    private var r18Binding: Binding<Bool> {
        Binding(
            get: { r18Enabled },
            set: { newValue in
                if newValue && !r18NoticeConfirmed {
                    showR18Notice = true
                } else {
                    r18Enabled = newValue
                }
            }
        )
    }

    private let perspectiveOptions = ["", "第一人称", "第三人称限知", "第三人称全知", "多视角交替"]

    var body: some View {
        CompatNavigationView {
            Group {
                switch mode {
                case .choose: chooseView
                case .blank: blankForm
                case .oneLine: oneLineView
                }
            }
            .navigationTitle(titleForMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("启用 R18 增强？", isPresented: $showR18Notice) {
                Button("同意并开启") {
                    // iOS 15：alert action 闭包内的状态写入可能被丢弃，延迟到下一主队列周期
                    DispatchQueue.main.async {
                        r18NoticeConfirmed = true
                        r18Enabled = true
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("说明：此功能仅为合规的 R18 写作提示词注入，用于增强小说文采与场景表现力，并非「破甲」或「越狱」提示词。\n\n提醒：如需更高级别的 R18 内容生成，请自行配置相应模型或 API 权限，本功能不涉及任何绕过模型安全策略的操作。\n\n免责声明：生成的所有内容均由您自行负责，与本应用开发者及运营方无关。")
            }
        }
    }

    private var titleForMode: String {
        switch mode {
        case .choose: return "新建作品"
        case .blank: return "空白建书"
        case .oneLine: return "一句话立项"
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
            Spacer()
        }
        .padding(AppTheme.spacing[3])
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

    // MARK: - 空白建书

    private var blankForm: some View {
        Form {
            Section("基本信息") {
                TextField("书名", text: $title)
                MultilineField(text: $synopsis, placeholder: "一句话梗概（可选）", minHeight: 56)
            }
            Section("叙事") {
                Picker("叙事视角", selection: $perspective) {
                    ForEach(perspectiveOptions, id: \.self) { option in
                        Text(option.isEmpty ? "未指定" : option).tag(option)
                    }
                }
                MultilineField(text: $styleGuide, placeholder: "风格约束（可选，续写时注入）", minHeight: 56)
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

                Toggle(isOn: r18Binding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R18 增强（虚构情色写作辅助）").font(.subheadline)
                        Text(r18Enabled ? "已开启：注入本地打包的 R18 写作规范（按语言二选一），强调色锁定血红" : "为本书开启成人向写作规范注入")
                            .font(.caption2)
                            .foregroundStyle(r18Enabled ? Color.red : .secondary)
                    }
                }
            }
        }
        .frame(maxHeight: 210)
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

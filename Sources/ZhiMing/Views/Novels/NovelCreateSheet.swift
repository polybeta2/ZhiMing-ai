import SwiftUI

/// 新建作品：空白建书 / 一句话立项 两个入口
struct NovelCreateSheet: View {
    @Environment(AppStore.self) private var store
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

    private let perspectiveOptions = ["", "第一人称", "第三人称限知", "第三人称全知", "多视角交替"]

    var body: some View {
        NavigationStack {
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
                    .foregroundStyle(.tint)
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
                TextField("一句话梗概（可选）", text: $synopsis, axis: .vertical)
                    .lineLimit(1...3)
            }
            Section("叙事") {
                Picker("叙事视角", selection: $perspective) {
                    ForEach(perspectiveOptions, id: \.self) { option in
                        Text(option.isEmpty ? "未指定" : option).tag(option)
                    }
                }
                TextField("风格约束（可选，续写时注入）", text: $styleGuide, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("强调色") {
                HStack(spacing: AppTheme.spacing[2]) {
                    ForEach(AppTheme.accentPresets.indices, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.accentPresets[index])
                            .frame(width: 32, height: 32)
                            .overlay {
                                if accentIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { accentIndex = index }
                    }
                    Spacer()
                }
                .padding(.vertical, AppTheme.spacing[0])
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
        novel.accentColorHex = AppTheme.accentPresets[accentIndex].hexString

        let volume = Volume(name: "第一卷", sortOrder: 1)
        volume.novel = novel
        novel.volumes.append(volume)

        store.novels.append(novel)
        store.save()
        onCreated(novel.id)
    }

    // MARK: - 一句话立项

    private var oneLineView: some View {
        VStack(spacing: AppTheme.spacing[3]) {
            Text("用一句话描述你的故事创意，AI 将生成可编辑的作品蓝图。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("例如：失忆的灯塔看守人收到一封写给自己的讣告…", text: $brief, axis: .vertical)
                .lineLimit(4...8)
                .padding(AppTheme.spacing[2])
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))

            Button {
                createFromBrief()
            } label: {
                Label("开始立项", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing[1])
            }
            .buttonStyle(.borderedProminent)
            .disabled(brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(AppTheme.spacing[3])
    }

    private func createFromBrief() {
        let text = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let displayTitle = text.count <= 14 ? text : String(text.prefix(14)) + "…"
        let novel = Novel(title: displayTitle, synopsis: text)
        novel.accentColorHex = AppTheme.accentPresets[0].hexString

        // 立项会话线程（Phase 8 状态机将读取 synopsis 作为初始创意）
        let thread = ChatThread(purpose: "creation")
        thread.novel = novel
        novel.chatThreads.append(thread)

        store.novels.append(novel)
        store.save()
        onCreated(novel.id)
    }
}

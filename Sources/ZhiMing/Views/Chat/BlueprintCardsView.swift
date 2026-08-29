#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 蓝图可编辑卡片组：书名/主题/梗概/视角/风格 + 角色列表 + 世界观列表 + 卷纲章纲
/// 每条可就地编辑、删除；条目可新增
struct BlueprintCardsView: View {
    @ObservedObject var vm: CreationSessionViewModel

    /// 桥接为无条件绑定（仅在 blueprint 非空时展示本视图）
    private var bp: Binding<NovelBlueprint> {
        Binding(
            get: { vm.blueprint ?? NovelBlueprint() },
            set: { vm.blueprint = $0 }
        )
    }

    /// 可选字符串 ↔ 空串 的桥接绑定
    private func str(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
            Label("作品蓝图（可编辑）", systemImage: "square.stack.3d.up")
                .font(.subheadline.weight(.semibold))

            if vm.blueprint != nil {
                basicFields
                charactersSection
                worldSection
                volumesSection
            }
        }
        .padding(AppTheme.spacing[2])
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))
    }

    // MARK: - 基础字段

    private var basicFields: some View {
        VStack(spacing: AppTheme.spacing[1]) {
            TextField("书名", text: str(bp.title_suggestion))
                .font(.headline)
            TextField("主题与基调", text: str(bp.theme))
                .font(.subheadline)
            MultilineField(text: str(bp.synopsis), placeholder: "故事梗概", minHeight: 56)
                .font(.subheadline)
            HStack {
                TextField("叙事视角", text: str(bp.perspective))
                    .font(.footnote)
                TextField("文风约束", text: str(bp.style_guide))
                    .font(.footnote)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - 角色

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            sectionHeader("角色", count: vm.blueprint?.characters.count ?? 0)
            ForEach(bp.characters) { $character in
                VStack(alignment: .leading, spacing: AppTheme.spacing[0]) {
                    HStack {
                        TextField("姓名", text: str($character.name))
                            .font(.subheadline.weight(.medium))
                        TextField("主角/配角", text: str($character.role))
                            .font(.caption)
                            .frame(width: 70)
                        Spacer()
                        deleteButton {
                            vm.blueprint?.characters.removeAll { $0.id == character.id }
                        }
                    }
                    TextField("外貌", text: str($character.appearance)).font(.caption)
                    TextField("性格", text: str($character.personality)).font(.caption)
                    TextField("目标", text: str($character.goal)).font(.caption)
                }
                .padding(AppTheme.spacing[1])
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            }
            addButton("添加角色") {
                vm.blueprint?.characters.append(BlueprintCharacter())
            }
        }
    }

    // MARK: - 世界观

    private var worldSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            sectionHeader("世界观", count: vm.blueprint?.worldbuilding.count ?? 0)
            ForEach(bp.worldbuilding) { $entry in
                VStack(alignment: .leading, spacing: AppTheme.spacing[0]) {
                    HStack {
                        TextField("分类（地点/势力/规则/物品）", text: str($entry.category))
                            .font(.caption)
                            .frame(maxWidth: 150, alignment: .leading)
                        TextField("名称", text: str($entry.name))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        deleteButton {
                            vm.blueprint?.worldbuilding.removeAll { $0.id == entry.id }
                        }
                    }
                    MultilineField(text: str($entry.content), placeholder: "设定内容", minHeight: 40)
                        .font(.caption)
                }
                .padding(AppTheme.spacing[1])
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            }
            addButton("添加条目") {
                vm.blueprint?.worldbuilding.append(BlueprintWorld())
            }
        }
    }

    // MARK: - 卷与章

    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            sectionHeader("卷纲与章纲", count: vm.blueprint?.volumes.count ?? 0)
            ForEach(bp.volumes) { $volume in
                VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                    HStack {
                        TextField("卷名", text: str($volume.name))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        deleteButton {
                            vm.blueprint?.volumes.removeAll { $0.id == volume.id }
                        }
                    }
                    MultilineField(text: str($volume.outline), placeholder: "卷纲", minHeight: 40)
                        .font(.caption)

                    ForEach($volume.chapters) { $chapter in
                        HStack(alignment: .top, spacing: AppTheme.spacing[1]) {
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("章标题", text: str($chapter.title))
                                    .font(.caption.weight(.medium))
                                MultilineField(text: str($chapter.detailed_outline), placeholder: "细纲", minHeight: 36)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            deleteButton {
                                volume.chapters.removeAll { $0.id == chapter.id }
                            }
                        }
                    }
                    // 长篇小说蓝图：该卷章节全无标题时，提供 AI 一次性补全标题
                    if vm.isEmptyVolumeTitles(volume) {
                        Button {
                            vm.generateChapterNames(volumeIndex: vm.blueprint?.volumes.firstIndex(where: { $0.id == volume.id }) ?? -1)
                        } label: {
                            Label("AI 生成本卷章节标题（\(volume.chapters.count) 章）",
                                  systemImage: "text.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isStreaming)
                    }
                    addButton("添加章节") {
                        volume.chapters.append(BlueprintChapter())
                    }
                }
                .padding(AppTheme.spacing[1])
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            }
            addButton("添加卷") {
                vm.blueprint?.volumes.append(BlueprintVolume())
            }
        }
    }

    // MARK: - 通用小组件

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title)（\(count)）")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
}
#endif

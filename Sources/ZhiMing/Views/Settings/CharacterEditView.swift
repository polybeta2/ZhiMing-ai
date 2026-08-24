import SwiftUI

/// 角色卡编辑：基础档案 + 当前状态区 + 参与近期剧情开关 + 别名列表
struct CharacterEditView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let novel: Novel
    let character: CharacterCard?        // nil = 新建

    @State private var name: String
    @State private var aliases: [String]
    @State private var newAlias = ""
    @State private var appearance: String
    @State private var personality: String
    @State private var background: String
    @State private var currentGoal: String
    @State private var currentLocation: String
    @State private var physicalState: String
    @State private var mentalState: String
    @State private var lastSeenChapterTitle: String
    @State private var isSceneRelevant: Bool

    init(novel: Novel, character: CharacterCard?) {
        self.novel = novel
        self.character = character
        _name = State(initialValue: character?.name ?? "")
        _aliases = State(initialValue: character?.aliases ?? [])
        _appearance = State(initialValue: character?.appearance ?? "")
        _personality = State(initialValue: character?.personality ?? "")
        _background = State(initialValue: character?.background ?? "")
        _currentGoal = State(initialValue: character?.currentGoal ?? "")
        _currentLocation = State(initialValue: character?.currentLocation ?? "")
        _physicalState = State(initialValue: character?.physicalState ?? "")
        _mentalState = State(initialValue: character?.mentalState ?? "")
        _lastSeenChapterTitle = State(initialValue: character?.lastSeenChapterTitle ?? "")
        _isSceneRelevant = State(initialValue: character?.isSceneRelevant ?? true)
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("基础档案") {
                    TextField("姓名", text: $name)
                    aliasesEditor
                    MultilineField(text: $appearance, placeholder: "外貌", minHeight: 48)
                    MultilineField(text: $personality, placeholder: "性格", minHeight: 48)
                    MultilineField(text: $background, placeholder: "背景", minHeight: 48)
                }

                Section {
                    MultilineField(text: $currentGoal, placeholder: "当前目标", minHeight: 44)
                    MultilineField(text: $currentLocation, placeholder: "当前位置", minHeight: 44)
                    MultilineField(text: $physicalState, placeholder: "身体状态", minHeight: 44)
                    MultilineField(text: $mentalState, placeholder: "心理状态", minHeight: 44)
                    MultilineField(text: $lastSeenChapterTitle, placeholder: "最近出场章节", minHeight: 44)
                } header: {
                    Text("当前状态")
                } footer: {
                    Text("当前状态随剧情推进手动更新，续写时注入上下文，防止人物状态漂移。")
                }

                Section("剧情参与") {
                    Toggle("参与近期剧情", isOn: $isSceneRelevant)
                }
            }
            .navigationTitle(character == nil ? "新建角色" : "编辑角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var aliasesEditor: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            Text("别名")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(aliases, id: \.self) { alias in
                HStack {
                    Text(alias)
                    Spacer()
                    Button {
                        aliases.removeAll { $0 == alias }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("添加别名", text: $newAlias)
                    .onSubmit { addAlias() }
                Button("添加") { addAlias() }
                    .disabled(newAlias.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addAlias() {
        let value = newAlias.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, !aliases.contains(value) else { return }
        aliases.append(value)
        newAlias = ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let target = character ?? CharacterCard(name: trimmedName)
        target.name = trimmedName
        target.aliases = aliases
        target.appearance = Self.nilIfEmpty(appearance)
        target.personality = Self.nilIfEmpty(personality)
        target.background = Self.nilIfEmpty(background)
        target.currentGoal = Self.nilIfEmpty(currentGoal)
        target.currentLocation = Self.nilIfEmpty(currentLocation)
        target.physicalState = Self.nilIfEmpty(physicalState)
        target.mentalState = Self.nilIfEmpty(mentalState)
        target.lastSeenChapterTitle = Self.nilIfEmpty(lastSeenChapterTitle)
        target.isSceneRelevant = isSceneRelevant

        if character == nil {
            target.novel = novel
            novel.characters.append(target)
        }
        store.save()
        dismiss()
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

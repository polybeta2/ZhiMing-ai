#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 原作档案详情：人物 / 时间线 / 世界观 三 Tab 可编辑 + token/状态 + 操作。
struct SourceProfileDetailView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var profile: SourceNovelProfile
    @Environment(\.dismiss) private var dismiss

    enum Tab: Int { case characters = 0, timeline, worldbuilding }

    @State private var tab: Tab = .characters
    @State private var showDelete = false
    @State private var showStylePicker = false

    private var boundStyleName: String? {
        profile.styleProfileID.flatMap { id in
            store.styleProfiles.first { $0.id == id }?.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            TabView(selection: $tab) {
                characterTab.tag(Tab.characters)
                timelineTab.tag(Tab.timeline)
                worldTab.tag(Tab.worldbuilding)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(AppTheme.Spring.standard, value: tab)
        }
        .navigationTitle(profile.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showStylePicker = true
                    } label: {
                        Label("文风绑定", systemImage: "textformat")
                    }
                    Button {
                        showDelete = true
                    } label: {
                        Label("删除档案", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showStylePicker) {
            stylePickerSheet
        }
        .sheet(isPresented: $showDelete) {
            DeleteConfirmSheet(
                title: "删除「\(profile.title)」档案？",
                message: "档案下的人物卡/事件/世界观将一并删除；引用该档案的同人书会被解除绑定。"
            ) {
                store.deleteSourceProfile(profile)
                SourceScanCache.clear(profile: profile.id)
                dismiss()
            }
        }
    }

    // MARK: 顶部信息条

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(profile.title).font(.title3.bold()).lineLimit(1)
                if profile.scanState.isComplete {
                    Text("已完成")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }
                Spacer()
            }
            Text("\(profile.scanState.totalChunks) 块 · token \(profile.scanState.tokensIn / 1000)k 入 / \(profile.scanState.tokensOut / 1000)k 出")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                styleLink
                if let author = profile.author, !author.isEmpty {
                    Text(author).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppTheme.spacing[3])
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var styleLink: some View {
        Button {
            showStylePicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "textformat")
                    .font(.caption2)
                Text(boundStyleName.map { "文风：\($0)" } ?? "绑定文风")
                    .font(.caption2)
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: 三 Tab

    private var characterTab: some View {
        List {
            ForEach(profile.characters.indices, id: \.self) { index in
                CharacterEditSection(
                    character: charBinding(index),
                    save: save,
                    onRemove: {
                        save()
                        profile.characters.remove(at: index)
                    }
                )
            }
            Section {
                Button {
                    profile.characters.append(CanonCharacter(name: "新角色"))
                    save()
                } label: {
                    Label("添加人物", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var timelineTab: some View {
        let grouped = Dictionary(grouping: profile.timeline) { $0.phase ?? "未分阶段" }
        let orderedKeys = grouped.keys.sorted()
        return List {
            ForEach(orderedKeys, id: \.self) { phase in
                let phaseIndices = profile.timeline.indices.filter {
                    profile.timeline[$0].phase ?? "未分阶段" == phase
                }
                Section(phase) {
                    ForEach(phaseIndices, id: \.self) { index in
                        EventEditSection(event: eventBinding(index), save: save)
                    }
                }
            }
            Section {
                Button {
                    profile.timeline.append(CanonEvent(summary: "新事件"))
                    save()
                } label: {
                    Label("添加事件", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var worldTab: some View {
        List {
            ForEach(profile.worldbuilding.indices, id: \.self) { index in
                WorldEditSection(world: worldBinding(index), save: save)
            }
            Section {
                Button {
                    profile.worldbuilding.append(CanonWorldEntry(category: "设定", name: "新条目", content: ""))
                    save()
                } label: {
                    Label("添加条目", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: 文风绑定选择

    private var stylePickerSheet: some View {
        CompatNavigationView {
            List {
                Section("档案绑定") {
                    Button {
                        profile.styleProfileID = nil
                        save()
                    } label: {
                        HStack {
                            Text("不绑定")
                            Spacer()
                            if profile.styleProfileID == nil { Image(systemName: "checkmark") }
                        }
                    }
                    .buttonStyle(.plain)
                    ForEach(store.styleProfiles) { style in
                        Button {
                            profile.styleProfileID = style.id
                            save()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.name)
                                    if !style.tags.isEmpty {
                                        Text(style.tags.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if profile.styleProfileID == style.id { Image(systemName: "checkmark") }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section(footer: Text("绑定后：以该档案立项的同人书创建时自动继承此文风，可在书内换绑。")) {
                    NavigationLink(destination: StyleLibraryView()) {
                        Text("管理风格库")
                    }
                }
            }
            .navigationTitle("文风绑定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showStylePicker = false }
                }
            }
        }
    }

    // MARK: 工具

    private func charBinding(_ index: Int) -> Binding<CanonCharacter> {
        Binding(get: {
            profile.characters.indices.contains(index) ? profile.characters[index] : CanonCharacter(name: "")
        }, set: { newValue in
            guard profile.characters.indices.contains(index) else { return }
            profile.characters[index] = newValue
            save()
        })
    }

    private func eventBinding(_ index: Int) -> Binding<CanonEvent> {
        Binding(get: {
            profile.timeline.indices.contains(index) ? profile.timeline[index] : CanonEvent(summary: "")
        }, set: { newValue in
            guard profile.timeline.indices.contains(index) else { return }
            profile.timeline[index] = newValue
            save()
        })
    }

    private func worldBinding(_ index: Int) -> Binding<CanonWorldEntry> {
        Binding(get: {
            profile.worldbuilding.indices.contains(index) ? profile.worldbuilding[index] : CanonWorldEntry(category: "", name: "", content: "")
        }, set: { newValue in
            guard profile.worldbuilding.indices.contains(index) else { return }
            profile.worldbuilding[index] = newValue
            save()
        })
    }

    private func save() {
        store.upsertSourceProfile(profile)
    }
}

// MARK: - 人物卡编辑区

private struct CharacterEditSection: View {
    @Binding var character: CanonCharacter
    let save: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("姓名", text: $character.name)
                .font(.headline)
            TextField("别名（顿号/逗号分隔）", text: aliasesText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                TextField("定位", text: $character.oneLine.stringBinding)
                TextField("角色", text: $character.role.stringBinding)
            }
            MultilineField(text: $character.personality.stringBinding, placeholder: "性格", minHeight: 44)
            MultilineField(text: $character.abilities.stringBinding, placeholder: "能力", minHeight: 44)
            relationshipsEditor
            arcEditor
            Button(role: .destructive) { onRemove() } label: {
                Label("删除人物", systemImage: "trash")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private var aliasesText: Binding<String> {
        Binding(
            get: { character.aliases.joined(separator: "，") },
            set: { character.aliases = FlexStringArray.splitList($0) }
        )
    }

    @ViewBuilder
    private var relationshipsEditor: some View {
        if !character.relationships.isEmpty {
            ForEach(character.relationships.indices, id: \.self) { index in
                HStack {
                    TextField("关系对象", text: $character.relationships[index].target)
                        .textFieldStyle(.roundedBorder)
                    TextField("关系", text: $character.relationships[index].relation)
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        character.relationships.remove(at: index)
                        save()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                }
            }
        }
        Button {
            character.relationships.append(CanonRelationship(target: "", relation: ""))
            save()
        } label: {
            Label("添加关系", systemImage: "plus")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var arcEditor: some View {
        if !character.arc.isEmpty {
            ForEach(character.arc.indices, id: \.self) { index in
                HStack {
                    TextField("阶段", text: $character.arc[index].stage)
                        .textFieldStyle(.roundedBorder)
                    TextField("变化", text: $character.arc[index].change)
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        character.arc.remove(at: index)
                        save()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                }
            }
        }
        Button {
            character.arc.append(CanonArc(stage: "", change: ""))
            save()
        } label: {
            Label("添加弧光阶段", systemImage: "plus")
                .font(.caption)
        }
    }
}

// MARK: - 事件编辑区

private struct EventEditSection: View {
    @Binding var event: CanonEvent
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MultilineField(text: $event.summary, placeholder: "事件一句话（含结果）", minHeight: 44)
            HStack {
                TextField("阶段", text: $event.phase.stringBinding)
                Picker("", selection: $event.importance) {
                    Text("重要").tag(Importance.major)
                    Text("次要").tag(Importance.minor)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            TextField("参与角色（逗号分隔）", text: participantsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MultilineField(text: $event.consequence.stringBinding, placeholder: "不可逆事实（可选）", minHeight: 40)
        }
        .padding(.vertical, 4)
    }

    private var participantsText: Binding<String> {
        Binding(
            get: { event.participants.joined(separator: "，") },
            set: { event.participants = FlexStringArray.splitList($0) }
        )
    }
}

// MARK: - 世界观条目编辑区

private struct WorldEditSection: View {
    @Binding var world: CanonWorldEntry
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: $world.name)
                    .font(.headline)
                TextField("分类", text: $world.category)
                    .font(.subheadline)
            }
            MultilineField(text: $world.content, placeholder: "内容", minHeight: 44)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Binding<String?> → Binding<String>

private extension Binding where Value == String? {
    /// 可空字段编辑桥接：空字符串 ↔ nil（输入清空时不写入 nil 之外的杂质）
    var stringBinding: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { newValue in
                self.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}
#endif
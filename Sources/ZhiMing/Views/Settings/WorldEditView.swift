import SwiftUI

/// 世界观条目编辑：分类 + 名称 + 内容
struct WorldEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let novel: Novel
    let entry: WorldEntry?               // nil = 新建

    @State private var category: String
    @State private var name: String
    @State private var content: String

    init(novel: Novel, entry: WorldEntry?) {
        self.novel = novel
        self.entry = entry
        _category = State(initialValue: entry?.category ?? "地点")
        _name = State(initialValue: entry?.name ?? "")
        _content = State(initialValue: entry?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("条目") {
                    Picker("分类", selection: $category) {
                        ForEach(WorldListView.categories, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                    TextField("名称", text: $name)
                }
                Section("内容") {
                    TextField("设定描述…", text: $content, axis: .vertical)
                        .lineLimit(6...16)
                }
            }
            .navigationTitle(entry == nil ? "新建条目" : "编辑条目")
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

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let target = entry ?? WorldEntry(category: category, name: trimmedName)
        target.category = category
        target.name = trimmedName
        target.content = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if entry == nil {
            target.novel = novel
            novel.worldEntries.append(target)
        }
        store.save()
        dismiss()
    }
}

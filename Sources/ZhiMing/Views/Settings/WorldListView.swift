import SwiftUI

/// 世界观条目列表：按 category 分 Section
struct WorldListView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel
    @State private var editing: WorldEntry?
    @State private var showNew = false
    @State private var deleting: WorldEntry?

    static let categories = ["地点", "势力", "规则", "物品", "其他"]

    private var grouped: [(category: String, entries: [WorldEntry])] {
        Self.categories.compactMap { category in
            let entries = novel.worldEntries.filter { $0.category == category }
            return entries.isEmpty ? nil : (category, entries)
        }
    }

    var body: some View {
        List {
            if novel.worldEntries.isEmpty {
                Section {
                    Text("还没有世界观条目。地点、势力、规则、物品等设定会按需注入续写上下文。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(grouped, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.entries) { entry in
                        Button {
                            editing = entry
                        } label: {
                            WorldRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleting = entry
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("世界观")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) {
            WorldEditView(novel: novel, entry: nil)
        }
        .sheet(item: $editing) { entry in
            WorldEditView(novel: novel, entry: entry)
        }
        .confirmationDialog(
            "删除「\(deleting?.name ?? "")」？",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let entry = deleting {
                    novel.worldEntries.removeAll { $0.id == entry.id }
                    store.save()
                }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        }
    }
}

private struct WorldRow: View {
    @ObservedObject var entry: WorldEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.name).font(.headline)
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, AppTheme.spacing[0])
        .contentShape(Rectangle())
    }
}

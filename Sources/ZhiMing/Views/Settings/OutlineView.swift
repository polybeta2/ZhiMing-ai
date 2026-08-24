import SwiftUI

/// 卷纲与章细纲编辑：卷列表（增删改卷名+卷纲），每卷下章节的细纲快捷编辑入口
struct OutlineView: View {
    @Environment(AppStore.self) private var store
    let novel: Novel

    @State private var renamingVolume: Volume?
    @State private var renameText = ""
    @State private var deletingVolume: Volume?
    @State private var editingChapter: Chapter?
    @State private var outlineDraft = ""

    var body: some View {
        List {
            if novel.volumes.isEmpty {
                Section {
                    Text("还没有卷。点击右上角 + 新建卷，再在卷下管理章节。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(novel.sortedVolumes) { volume in
                Section {
                    TextField("卷纲（本卷走向概述）…", text: Binding(
                        get: { volume.outline ?? "" },
                        set: { volume.outline = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                        .lineLimit(2...6)
                        .onChange(of: volume.outline) { _, _ in store.save() }

                    if volume.chapters.isEmpty {
                        Text("本卷暂无章节，可在「章节」页签添加。")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(volume.sortedChapters) { chapter in
                        Button {
                            outlineDraft = chapter.detailedOutline ?? ""
                            editingChapter = chapter
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chapter.title)
                                    .font(.subheadline.weight(.medium))
                                Text(chapter.detailedOutline ?? "未填写细纲")
                                    .font(.footnote)
                                    .foregroundStyle(chapter.detailedOutline == nil ? .tertiary : .secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(volume.name)
                }
                .contextMenu {
                    Button {
                        renameText = volume.name
                        renamingVolume = volume
                    } label: {
                        Label("重命名卷", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingVolume = volume
                    } label: {
                        Label("删除卷", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("大纲")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("重命名卷", isPresented: Binding(
            get: { renamingVolume != nil },
            set: { if !$0 { renamingVolume = nil } }
        )) {
            TextField("卷名", text: $renameText)
            Button("取消", role: .cancel) { renamingVolume = nil }
            Button("保存") {
                if let volume = renamingVolume {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        volume.name = trimmed
                        store.save()
                    }
                }
                renamingVolume = nil
            }
        }
        .confirmationDialog(
            "删除「\(deletingVolume?.name ?? "")」？",
            isPresented: Binding(get: { deletingVolume != nil }, set: { if !$0 { deletingVolume = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除卷及其全部章节", role: .destructive) {
                if let volume = deletingVolume {
                    novel.volumes.removeAll { $0.id == volume.id }
                    renormalizeVolumes()
                    store.save()
                }
                deletingVolume = nil
            }
            Button("取消", role: .cancel) { deletingVolume = nil }
        } message: {
            Text("卷下的章节与快照将一并删除。")
        }
        .sheet(item: $editingChapter) { chapter in
            NavigationStack {
                Form {
                    Section("本章细纲") {
                        TextField("这一章的场景、冲突与推进…", text: $outlineDraft, axis: .vertical)
                            .lineLimit(6...16)
                    }
                }
                .navigationTitle(chapter.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { editingChapter = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let trimmed = outlineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            chapter.detailedOutline = trimmed.isEmpty ? nil : trimmed
                            store.save()
                            editingChapter = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func addVolume() {
        let volume = Volume(name: "第\(novel.volumes.count + 1)卷", sortOrder: novel.volumes.count + 1)
        volume.novel = novel
        novel.volumes.append(volume)
        store.save()
    }

    private func renormalizeVolumes() {
        for (index, volume) in novel.sortedVolumes.enumerated() {
            volume.sortOrder = index + 1
        }
    }
}

import SwiftUI

/// 卷纲与章细纲编辑：卷列表（增删改卷名+卷纲），每卷下章节的细纲快捷编辑入口
struct OutlineView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel

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
                VolumeOutlineSection(store: store, volume: volume)
            }
        }
        .navigationTitle("大纲")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addVolume() {
        let volume = Volume(name: "第\(novel.volumes.count + 1)卷", sortOrder: novel.volumes.count + 1)
        volume.novel = novel
        novel.volumes.append(volume)
        store.save()
    }
}

/// 单卷区块：卷名/卷纲编辑（防抖保存）+ 章细纲快捷编辑
private struct VolumeOutlineSection: View {
    @ObservedObject var store: AppStore
    @ObservedObject var volume: Volume

    @State private var outlineDraft = ""
    @State private var syncDraft = false
    @State private var saveTask: Task<Void, Never>?
    @State private var editingChapter: Chapter?
    @State private var chapterOutlineDraft = ""
    @State private var renamingVolume = false
    @State private var renameText = ""
    @State private var deletingVolume = false

    var body: some View {
        Section {
            MultilineField(text: $outlineDraft, placeholder: "卷纲（本卷走向概述）…", minHeight: 56)
                .zmOnChange(of: outlineDraft) { newValue in
                    guard !syncDraft else { return }
                    volume.outline = newValue.isEmpty ? nil : newValue
                    scheduleSave()
                }

            if volume.chapters.isEmpty {
                Text("本卷暂无章节，可在「章节」页签添加。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            ForEach(volume.sortedChapters) { chapter in
                Button {
                    chapterOutlineDraft = chapter.detailedOutline ?? ""
                    editingChapter = chapter
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chapter.title)
                            .font(.subheadline.weight(.medium))
                        Text(chapter.detailedOutline ?? "未填写细纲")
                            .font(.footnote)
                            .foregroundColor(chapter.detailedOutline == nil ? Color(uiColor: .tertiaryLabel) : .secondary)
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
                renamingVolume = true
            } label: {
                Label("重命名卷", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingVolume = true
            } label: {
                Label("删除卷", systemImage: "trash")
            }
        }
        .onAppear {
            syncDraft = true
            outlineDraft = volume.outline ?? ""
            DispatchQueue.main.async { syncDraft = false }
        }
        .sheet(isPresented: $renamingVolume) {
            RenameSheet(title: "重命名卷", placeholder: "卷名", initialText: renameText) { newValue in
                volume.name = newValue
                store.save()
            }
        }
        .confirmationDialog(
            "删除「\(volume.name)」？",
            isPresented: $deletingVolume,
            titleVisibility: .visible
        ) {
            Button("删除卷及其全部章节", role: .destructive) {
                if let novel = volume.novel {
                    novel.volumes.removeAll { $0.id == volume.id }
                    for (index, v) in novel.sortedVolumes.enumerated() { v.sortOrder = index + 1 }
                    store.save()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("卷下的章节与快照将一并删除。")
        }
        .sheet(item: $editingChapter) { chapter in
            CompatNavigationView {
                Form {
                    Section("本章细纲") {
                        MultilineField(text: $chapterOutlineDraft, placeholder: "这一章的场景、冲突与推进…", minHeight: 140)
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
                            let trimmed = chapterOutlineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            chapter.detailedOutline = trimmed.isEmpty ? nil : trimmed
                            store.save()
                            editingChapter = nil
                        }
                    }
                }
            }
        }
    }

    /// 卷纲编辑防抖保存
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            store.save()
        }
    }
}

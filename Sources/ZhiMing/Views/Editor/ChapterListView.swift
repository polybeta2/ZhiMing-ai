import SwiftUI

/// 卷→章两级列表；章级操作菜单（新增/重命名/删除/上移下移）
/// 章行：标题 + 字数 + 摘要状态徽标（已建档/未建档）
struct ChapterListView: View {
    @Environment(AppStore.self) private var store
    let novel: Novel

    @State private var renaming: Chapter?
    @State private var renameText = ""
    @State private var deleting: Chapter?

    var body: some View {
        List {
            if novel.volumes.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("还没有卷")
                            .font(.headline)
                        Text("点击右上角 + 新建第一卷，再在卷下添加章节。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppTheme.spacing[1])
                }
            }
            ForEach(novel.sortedVolumes) { volume in
                Section(volume.name) {
                    ForEach(volume.sortedChapters) { chapter in
                        NavigationLink {
                            ChapterEditorView(chapter: chapter)
                        } label: {
                            ChapterRow(chapter: chapter)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameText = chapter.title
                                renaming = chapter
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button {
                                move(chapter, in: volume, up: true)
                            } label: {
                                Label("上移", systemImage: "arrow.up")
                            }
                            .disabled(chapter.id == volume.sortedChapters.first?.id)
                            Button {
                                move(chapter, in: volume, up: false)
                            } label: {
                                Label("下移", systemImage: "arrow.down")
                            }
                            .disabled(chapter.id == volume.sortedChapters.last?.id)
                            Button(role: .destructive) {
                                deleting = chapter
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    Button {
                        addChapter(to: volume)
                    } label: {
                        Label("新增章节", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .alert("重命名章节", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("章节标题", text: $renameText)
            Button("取消", role: .cancel) { renaming = nil }
            Button("保存") {
                if let chapter = renaming {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        chapter.title = trimmed
                        store.save()
                    }
                }
                renaming = nil
            }
        }
        .confirmationDialog(
            "删除「\(deleting?.title ?? "")」？",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除章节及其快照", role: .destructive) {
                if let chapter = deleting, let volume = chapter.volume {
                    volume.chapters.removeAll { $0.id == chapter.id }
                    volume.normalizeChapterOrder()
                    store.save()
                }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        }
    }

    private func addVolume() {
        let volume = Volume(name: "第\(novel.volumes.count + 1)卷", sortOrder: novel.volumes.count + 1)
        volume.novel = novel
        novel.volumes.append(volume)
        store.save()
    }

    private func addChapter(to volume: Volume) {
        let chapter = Chapter(title: "新章 \(volume.chapters.count + 1)", sortOrder: volume.chapters.count + 1)
        chapter.volume = volume
        volume.chapters.append(chapter)
        store.save()
    }

    private func move(_ chapter: Chapter, in volume: Volume, up: Bool) {
        let sorted = volume.sortedChapters
        guard let index = sorted.firstIndex(where: { $0.id == chapter.id }) else { return }
        let target = up ? index - 1 : index + 1
        guard target >= 0, target < sorted.count else { return }
        let temp = sorted[index].sortOrder
        sorted[index].sortOrder = sorted[target].sortOrder
        sorted[target].sortOrder = temp
        store.save()
    }
}

private struct ChapterRow: View {
    let chapter: Chapter

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            summaryBadge
        }
        .padding(.vertical, AppTheme.spacing[0])
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var summaryBadge: some View {
        if chapter.summary != nil {
            Label("已建档", systemImage: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        } else {
            Label("未建档", systemImage: "circle.dotted")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

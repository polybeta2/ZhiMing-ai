import SwiftUI

/// 卷→章两级列表；章级操作菜单（新增/重命名/删除/上移下移）
/// 章行：标题 + 字数 + 摘要状态徽标（已建档/未建档）
struct ChapterListView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel

    @State private var renaming: Chapter?
    @State private var renameText = ""

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
                VolumeSection(
                    store: store,
                    novel: novel,
                    volume: volume,
                    onRename: { chapter in
                        renameText = chapter.title
                        renaming = chapter
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            RenameSheet(
                title: "重命名章节",
                placeholder: "章节标题",
                initialText: renameText
            ) { newValue in
                if let chapter = renaming {
                    chapter.title = newValue
                    store.save()
                }
                renaming = nil
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

/// 单卷区块：观察 volume 自身，章增删/移动即时刷新
private struct VolumeSection: View {
    @ObservedObject var store: AppStore
    @ObservedObject var novel: Novel
    @ObservedObject var volume: Volume

    var onRename: (Chapter) -> Void

    @State private var deleting: Chapter?

    var body: some View {
        Section(volume.name) {
            ForEach(volume.sortedChapters) { chapter in
                NavigationLink(destination: ChapterEditorView(chapter: chapter)) {
                    ChapterRow(chapter: chapter)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        onRename(chapter)
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button {
                        move(chapter, up: true)
                    } label: {
                        Label("上移", systemImage: "arrow.up")
                    }
                    .disabled(chapter.id == volume.sortedChapters.first?.id)
                    Button {
                        move(chapter, up: false)
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

                // 删除确认内联卡（v1.5.2 教训：系统弹窗按钮动作在本项目目标系统上不可靠；
                // 该卡与普通视图按钮同级，已被大纲页删卷路径验证可用）
                if deleting?.id == chapter.id {
                    InlineConfirmCard(
                        title: "删除「\(chapter.title)」？",
                        message: "该章的正文、版本快照与摘要将一并删除，无法恢复。",
                        confirmLabel: "确认删除章节",
                        onConfirm: {
                            deleting = nil
                            volume.chapters.removeAll { $0.id == chapter.id }
                            volume.normalizeChapterOrder()
                            store.save()
                        },
                        onCancel: { deleting = nil }
                    )
                }
            }
            Button {
                addChapter()
            } label: {
                Label("新增章节", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
    }

    private func addChapter() {
        let chapter = Chapter(title: "新章 \(volume.chapters.count + 1)", sortOrder: volume.chapters.count + 1)
        chapter.volume = volume
        volume.chapters.append(chapter)
        store.save()
    }

    private func move(_ chapter: Chapter, up: Bool) {
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
    @ObservedObject var chapter: Chapter

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
                .foregroundStyle(Color.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
        } else {
            Label("未建档", systemImage: "circle.dotted")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

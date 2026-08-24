import SwiftUI

/// 首页：作品卡片列表（对标 Kelivo 会话列表卡片行）
struct NovelListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showCreate = false
    @State private var renamingNovel: Novel?
    @State private var renameText = ""
    @State private var deletingNovel: Novel?
    /// 创建后自动进入作品（iOS 15 用隐藏 NavigationLink 实现）
    @State private var autoOpenNovel: Novel?

    private var sortedNovels: [Novel] {
        store.novels.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        CompatNavigationView {
            List {
                if store.novels.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("开始你的第一部长篇")
                                .font(.headline)
                            Text("点击右上角 + ：空白建书，或用一句话创意让 AI 生成完整蓝图。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, AppTheme.spacing[2])
                    }
                }
                ForEach(sortedNovels) { novel in
                    NavigationLink(destination: NovelDetailView(novel: novel)) {
                        NovelCardRow(novel: novel)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            renameText = novel.title
                            renamingNovel = novel
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingNovel = novel
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("织命")
            .background(autoOpenLink)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppTheme.spacing[2]) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                        Button {
                            showCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                NovelCreateSheet { createdID in
                    showCreate = false
                    autoOpenNovel = store.novels.first(where: { $0.id == createdID })
                }
            }
            .sheet(isPresented: Binding(
                get: { renamingNovel != nil },
                set: { if !$0 { renamingNovel = nil } }
            )) {
                RenameSheet(
                    title: "重命名作品",
                    placeholder: "书名",
                    initialText: renameText
                ) { newValue in
                    if let novel = renamingNovel {
                        novel.title = newValue
                        novel.updatedAt = .now
                        store.save()
                    }
                    renamingNovel = nil
                }
            }
            .confirmationDialog(
                "删除「\(deletingNovel?.title ?? "")」？",
                isPresented: Binding(
                    get: { deletingNovel != nil },
                    set: { if !$0 { deletingNovel = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除作品及其全部章节与设定", role: .destructive) {
                    if let novel = deletingNovel { store.deleteNovel(novel) }
                    deletingNovel = nil
                }
                Button("取消", role: .cancel) { deletingNovel = nil }
            } message: {
                Text("作品下的卷、章节、角色、世界观与聊天记录将一并删除，无法恢复。")
            }
        }
    }

    /// 创建作品后自动推入详情（iOS 15 隐藏链接方案）
    private var autoOpenLink: some View {
        Group {
            if let novel = autoOpenNovel {
                NavigationLink(
                    destination: NovelDetailView(novel: novel),
                    isActive: Binding(
                        get: { autoOpenNovel != nil },
                        set: { if !$0 { autoOpenNovel = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            }
        }
    }
}

/// 卡片行：圆形色块（作品色）+ 标题 + 副标题 + 相对时间
private struct NovelCardRow: View {
    @ObservedObject var novel: Novel

    private var subtitle: String {
        if let last = latestChapterTitle {
            return "最近：\(last)"
        }
        return novel.synopsis.isEmpty ? "暂无梗概" : novel.synopsis
    }

    private var latestChapterTitle: String? {
        let chapters = novel.volumes.flatMap(\.chapters)
        guard let latest = chapters.max(by: { $0.updatedAt < $1.updatedAt }),
              latest.wordCount > 0 else { return nil }
        return latest.title
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            Circle()
                .fill((novel.accentColorHex.flatMap { Color(hex: $0) } ?? AppTheme.accentPresets[0]).opacity(0.85))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "book.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(novel.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(Self.relative(novel.updatedAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppTheme.spacing[1])
        .contentShape(Rectangle())
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

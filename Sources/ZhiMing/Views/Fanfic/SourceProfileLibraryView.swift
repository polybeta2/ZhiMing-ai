#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import CoreFoundation
import ZhiMingCore

/// 一次扫描任务（sheet identity：进入即建 VM 并启动扫描）
struct ScanJob: Identifiable {
    let id = UUID()
    let text: String
    let title: String
    let mode: ScanMode
    let batchSize: Int
    let provider: ProviderConfig
    let continuation: Bool
}

/// 待分析文件信息（档位选择页展示章数/字数用；批量模式复用）
private struct PendingFile: Identifiable {
    let id = UUID()
    let text: String
    let title: String
    let chapterCount: Int
}

/// 扫描进度承载视图：负责持有 VM 生命周期（档案库与续写导入共用）
struct ScanProgressWrap: View {
    let job: ScanJob
    let store: AppStore
    var onProfileReady: ((SourceNovelProfile) -> Void)? = nil
    @StateObject private var vm: SourceScanViewModel
    @Environment(\.dismiss) private var dismiss

    init(job: ScanJob, store: AppStore, onProfileReady: ((SourceNovelProfile) -> Void)? = nil) {
        self.job = job
        self.store = store
        self.onProfileReady = onProfileReady
        _vm = StateObject(wrappedValue: SourceScanViewModel(provider: job.provider, store: store))
    }

    var body: some View {
        SourceScanProgressSheet(vm: vm) { profile in
            if let profile { onProfileReady?(profile) }
            dismiss()
        }
        .onAppear {
            vm.start(graphText: job.text, title: job.title, mode: job.mode,
                     batchSize: job.batchSize, continuation: job.continuation)
        }
    }
}

/// 原作档案库：一本原作一个档案（人物/事件/世界观/文风绑定），txt 导入分析。
struct SourceProfileLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showImporter = false
    /// origins 文件夹导入
    @State private var showOriginPicker = false
    @State private var showModePicker = false
    /// 确认档位后 → 启动扫描 sheet
    @State private var activeJob: ScanJob?
    @State private var deletingProfile: SourceNovelProfile?
    @State private var importError: String?
    /// 批量复制分析：先选文件（fileImporter），成功后进 BatchCopySheet
    @State private var batchMode = false
    @State private var batchSource: PendingFile?

    private var sortedProfiles: [SourceNovelProfile] {
        store.sourceProfiles.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if store.sourceProfiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .navigationTitle("原作档案库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showImporter = true
                    } label: {
                        Label("文件导入（系统文件）", systemImage: "doc.badge.plus")
                    }
                    Button {
                        showOriginPicker = true
                    } label: {
                        Label("从 origins 文件夹导入", systemImage: "folder.fill.badge.plus")
                    }
                    Button {
                        batchMode = true
                        showImporter = true
                    } label: {
                        Label("批量复制分析（免费外部 AI）", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Label("导入分析", systemImage: "doc.badge.plus")
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .utf8PlainText]) { result in
            if case .success(let url) = result { loadFile(url) }
        }
        .sheet(isPresented: $showOriginPicker) {
            originFolderSheet
        }
        .sheet(item: $batchSource) { pending in
            BatchCopySheet(text: pending.text, bookTitle: pending.title, store: store)
        }
        .sheet(isPresented: $showModePicker) {
            modePickerSheet
        }
        .sheet(item: $activeJob) { job in
            ScanProgressWrap(job: job, store: store)
        }
        .sheet(item: $deletingProfile) { profile in
            DeleteConfirmSheet(
                title: "删除「\(profile.title)」档案？",
                message: "档案下的人物卡/事件/世界观将一并删除；引用该档案的同人书会被解除绑定。"
            ) {
                store.deleteSourceProfile(profile)
                SourceScanCache.clear(profile: profile.id)
            }
        }
        .alert("导入失败", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmptyStateView(title: "还没有原作档案", systemImage: "books.vertical",
                           description: "导入一本 txt 小说，提炼人物/事件/世界观，作为同人创作的防 OOC 地基")
            Button {
                showOriginPicker = true
            } label: {
                Label("从 origins 文件夹导入", systemImage: "folder.fill.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            Button {
                showImporter = true
            } label: {
                Label("文件导入（系统文件）", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 列表

    private var profileList: some View {
        List {
            ForEach(sortedProfiles) { profile in
                NavigationLink(destination: SourceProfileDetailView(profile: profile)) {
                    SourceProfileRow(profile: profile, store: store)
                }
            }
            .onDelete { indexSet in
                if let first = indexSet.first {
                    deletingProfile = sortedProfiles[first]
                }
            }
        }
    }

    // MARK: 档位选择

    @State private var chosenMode: ScanMode = .fast
    /// 自动批量：单次请求分析的章数（默认 3）
    @State private var chosenBatchSize = 3

    /// 待分析文件（含切章统计）
    @State private var pendingScan: PendingFile?

    private var modePickerSheet: some View {
        CompatNavigationView {
            Form {
                Section(footer: Text("快扫每章只取头尾两窗（约 44% 采样，省 token）；精扫按全章整块推进（更完整但更贵）。都可以随时暂停续跑。")) {
                    Picker("扫描档位", selection: $chosenMode) {
                        Text("快扫").tag(ScanMode.fast)
                        Text("精扫").tag(ScanMode.full)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("批量章数", selection: $chosenBatchSize) {
                        ForEach(1...10, id: \.self) { n in
                            Text(n == 1 ? "逐章（1）" : "\(n) 章").tag(n)
                        }
                    }
                    Text("单次请求携带多章正文由 AI 逐章返回微摘要，请求数更少、总耗时更短。按模型上下文调整：Gemini 建议 5，DeepSeek Pro 约 20（这里按模型输入限额保守给 10 封顶），DeepSeek App Flash 30~50 可在外部分析使用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("自动批量")
                } footer: {
                    Text("默认 3 章/请求，兼顾速度与上下文安全。")
                }
                if let pending = pendingScan {
                    Section("文件") {
                        Text(pending.title)
                            .font(.subheadline)
                        HStack(spacing: 6) {
                            Image(systemName: "text.book.closed")
                                .foregroundStyle(Color.accentColor)
                            Text("已识别 \(pending.chapterCount) 章 · \(pending.text.count) 字")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Label("切章完成：全书按章节标记拆分，可直接开始分析。", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("开始分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showModePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        guard let provider = store.defaultProvider,
                              let pending = pendingScan else { return }
                        activeJob = ScanJob(text: pending.text, title: pending.title,
                                            mode: chosenMode, batchSize: chosenBatchSize,
                                            provider: provider, continuation: false)
                        showModePicker = false
                    }
                    .disabled(store.defaultProvider == nil)
                }
            }
        }
    }

    // MARK: - origins 文件夹导入（LiveContainer 无法走系统文件保存路径，改为引导放入本地目录）

    /// 列出目录 txt（进入 sheet 时刷新）
    private var originFiles: [URL] { SourceOriginFolder.listTextFiles() }

    private var originFolderSheet: some View {
        CompatNavigationView {
            Group {
                if originFiles.isEmpty {
                    VStack(spacing: 12) {
                        EmptyStateView(title: "origins 文件夹是空的", systemImage: "folder",
                                       description: "把要分析的小说 txt 放进这个文件夹，返回本页即可看到并导入")
                        originHowTo
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            ForEach(originFiles, id: \.path) { url in
                                Button {
                                    showOriginPicker = false
                                    // 等 origins sheet 收起后再弹档位选择（避免 sheet 叠 sheet）
                                    DispatchQueue.main.async { presentScan(url: url) }
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(Color.accentColor)
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Section {
                            originHowTo
                        }
                    }
                }
            }
            .navigationTitle("origins 文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showOriginPicker = false }
                }
            }
        }
    }

    /// 引导文案：如何把 txt 放入 origins（文件 App / LiveContainer 文件面板）
    private var originHowTo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("如何放入 txt", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
            Text("1. 打开系统「文件」App → 我的 iPhone → 织命 → origins 文件夹（LiveContainer：在它的文件面板中进入本 App 的沙盒目录）")
            Text("2. 将小说 txt 复制/分享进该文件夹（UTF-8 或 GBK 编码均可）")
            Text("3. 回到本页，文件会出现在列表里，选中即可开始分析")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 文件导入（fileImporter 与 origins 双通道共用 presentScan）

    private func loadFile(_ url: URL) {
        presentScan(url: url)
    }

    /// 读文件 → 编码识别 → 切章统计 → 弹档位选择（fileImporter 与 origins 共用）
    private func presentScan(url: URL) {
        switch SourceTextFileLoader.loadText(from: url) {
        case .failure(let message):
            importError = message
        case .success(let body):
            let title = url.deletingPathExtension().lastPathComponent
            if batchMode {
                batchMode = false
                batchSource = PendingFile(text: body, title: title, chapterCount: 0)
                return
            }
            Task {
                let chapterCount = await Task.detached(priority: .userInitiated) {
                    StyleChapterSampler.split(body).count
                }.value
                await MainActor.run {
                    pendingScan = PendingFile(text: body, title: title, chapterCount: chapterCount)
                    chosenMode = .fast
                    showModePicker = true
                }
            }
        }
    }
}

// MARK: - 档案卡片行

private struct SourceProfileRow: View {
    @ObservedObject var profile: SourceNovelProfile
    let store: AppStore

    private var statusLabel: (String, Color) {
        let s = profile.scanState
        if s.isComplete { return ("已完成", .green) }
        if s.doneChunks > 0 || s.stage == .paused || s.stage == .mapping || s.stage == .reducing {
            return ("部分完成", .orange)
        }
        if s.doneChunks == 0 && s.stage == .done { return ("已完成", .green) }
        return ("未分析", .gray)
    }

    private var boundStyleName: String? {
        profile.styleProfileID.flatMap { id in
            store.styleProfiles.first { $0.id == id }?.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.title).font(.headline).lineLimit(1)
                Text(statusLabel.0)
                    .font(.caption2.bold())
                    .foregroundColor(statusLabel.1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusLabel.1.opacity(0.12), in: Capsule())
            }
            if let author = profile.author, !author.isEmpty {
                Text(author).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(profile.meta.scanMode == .fast ? "快扫" : "精扫")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                Text("\(profile.meta.totalChapters) 章 · \(profile.meta.totalChars / 10000) 万字 · 人物 \(profile.characters.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let name = boundStyleName {
                Text("文风：\(name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
#endif
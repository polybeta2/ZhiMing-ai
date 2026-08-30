#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import ZhiMingCore

/// 续写导入：选 txt → 浏览章节 → 选「从第 X 章续写」→ 分析（API 自动 / 批量复制）→ 产出续写档案。
/// 上游把文本截断为 1~X 章再进扫描，批量复制页因此天然只列 1~X 章。
struct ContinuationImportSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// 分析完成回调（由 NovelCreateSheet 建书）
    var onProfileReady: (SourceNovelProfile) -> Void

    private struct LoadedBook {
        let title: String
        let chapters: [StyleChapterSampler.SampleChapter]
    }

    @State private var book: LoadedBook?
    @State private var showImporter = false
    @State private var showOriginPicker = false
    @State private var importError: String?
    /// 从第 X 章续写（1-based，默认最后一章）
    @State private var continueFrom = 1

    private enum AnalysisPath: String, CaseIterable, Identifiable {
        case api = "API 自动分析"
        case batchCopy = "批量复制（免费外部 AI）"
        var id: String { rawValue }
    }
    @State private var analysisPath: AnalysisPath = .api
    @State private var chosenMode: ScanMode = .fast
    @State private var chosenBatchSize = 3

    @State private var activeJob: ScanJob?
    @State private var batchJob: BatchText?

    /// 批量复制入口载荷（sheet item）
    private struct BatchText: Identifiable {
        let id = UUID()
        let text: String
        let title: String
    }

    var body: some View {
        CompatNavigationView {
            Group {
                if let book {
                    chapterForm(book)
                } else {
                    pickSourceView
                }
            }
            .navigationTitle(book == nil ? "续写小说" : "选择续写起点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .utf8PlainText]) { result in
            if case .success(let url) = result { loadBook(url: url) }
        }
        .sheet(isPresented: $showOriginPicker) { originPicker }
        .sheet(item: $activeJob) { job in
            ScanProgressWrap(job: job, store: store) { profile in
                onProfileReady(profile)
            }
        }
        .sheet(item: $batchJob) { job in
            BatchCopySheet(text: job.text, bookTitle: job.title, store: store, continuation: true) { profile in
                onProfileReady(profile)
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

    // MARK: 选源（fileImporter + origins 双通道）

    private var pickSourceView: some View {
        VStack(spacing: AppTheme.spacing[3]) {
            EmptyStateView(title: "选择要续写的小说", systemImage: "square.and.pencil",
                           description: "导入断更/烂尾/自己未写完的小说 txt，选择从第几章开始续写")
            Button {
                showImporter = true
            } label: {
                Label("文件导入（系统文件）", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            Button {
                showOriginPicker = true
            } label: {
                Label("从 origins 文件夹导入", systemImage: "folder.fill.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacing[3])
    }

    /// origins 目录文件列表（LiveContainer 兼容通道）
    private var originPicker: some View {
        CompatNavigationView {
            List {
                ForEach(SourceOriginFolder.listTextFiles(), id: \.path) { url in
                    Button {
                        showOriginPicker = false
                        DispatchQueue.main.async { loadBook(url: url) }
                    } label: {
                        Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
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

    // MARK: 章节选择 + 分析设置

    private func chapterForm(_ book: LoadedBook) -> some View {
        Form {
            Section(footer: Text("默认从最后一章续写（断更续写）。选中间章 = 写自己的 if 线，其后原文将被忽略。")) {
                Picker("从第几章续写", selection: $continueFrom) {
                    ForEach(1...book.chapters.count, id: \.self) { n in
                        Text("第 \(n) 章 · \(book.chapters[n - 1].marker)").tag(n)
                    }
                }
                Label("已识别 \(book.chapters.count) 章 · 将分析第 1~\(continueFrom) 章", systemImage: "text.book.closed")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Section("分析方式") {
                Picker("方式", selection: $analysisPath) {
                    ForEach(AnalysisPath.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                if analysisPath == .api {
                    Picker("扫描档位", selection: $chosenMode) {
                        Text("快扫").tag(ScanMode.fast)
                        Text("精扫").tag(ScanMode.full)
                    }
                    .pickerStyle(.segmented)
                    Picker("批量章数", selection: $chosenBatchSize) {
                        ForEach(1...10, id: \.self) { n in
                            Text(n == 1 ? "逐章（1）" : "\(n) 章").tag(n)
                        }
                    }
                } else {
                    Text("每批章数与复制流程在下一步设置（Gemini 建议 5，DeepSeek Pro 约 20，Flash 30~50）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    startAnalysis(book: book)
                } label: {
                    Label("开始分析（第 1~\(continueFrom) 章）", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.defaultProvider == nil && analysisPath == .api)
                if store.defaultProvider == nil, analysisPath == .api {
                    Text("API 自动分析需先在「设置 → 模型服务」配置服务商；或改用批量复制。")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: 动作

    private func loadBook(url: URL) {
        switch SourceTextFileLoader.loadText(from: url) {
        case .failure(let message):
            importError = message
        case .success(let text):
            let chapters = StyleChapterSampler.split(text)
            guard !chapters.isEmpty else {
                importError = "未识别到章节标记（第X章/Chapter X），无法选择续写起点。请检查文件格式。"
                return
            }
            book = LoadedBook(title: url.deletingPathExtension().lastPathComponent, chapters: chapters)
            continueFrom = chapters.count     // 默认最后一章（断更续写）
        }
    }

    /// 1~X 章截断文本（续写分析范围；marker+body 拼回，重切章无损）
    private func truncatedText(_ book: LoadedBook) -> String {
        book.chapters.prefix(continueFrom)
            .map { "\($0.marker)\n\($0.body)" }
            .joined(separator: "\n\n")
    }

    private func startAnalysis(book: LoadedBook) {
        let text = truncatedText(book)
        switch analysisPath {
        case .api:
            guard let provider = store.defaultProvider else { return }
            activeJob = ScanJob(text: text, title: book.title, mode: chosenMode,
                                batchSize: chosenBatchSize, provider: provider, continuation: true)
        case .batchCopy:
            batchJob = BatchText(text: text, title: book.title)
        }
    }
}
#endif
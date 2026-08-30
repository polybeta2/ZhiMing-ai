#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import ZhiMingCore

/// 蒸馏向导：来源（粘贴/导入文件/书库选书）→ 分阶段进度 → 完成自动入库。
/// 传入 augmentTarget 时为「追加样本」模式：结果合并进该档案（层字段以新样本为准，规则并集）。
struct StyleDistillSheet: View {
    private enum SourceKind: String, CaseIterable, Identifiable {
        case paste = "粘贴"
        case file = "导入文件"
        case book = "书库选书"
        var id: String { rawValue }
    }

    var augmentTarget: StyleProfile? = nil

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = StyleDistillationViewModel()
    @State private var kind: SourceKind = .paste
    @State private var pastedText = ""
    @State private var importedText = ""
    @State private var selectedBookID: UUID?
    @State private var sourceNote = ""
    @State private var showImporter = false
    @State private var saved = false
    /// 上次未完成的蒸馏（S2 已缓存），可从风格卡阶段恢复
    @State private var cachedResume: StyleDistillCache.Payload?
    // 大样本（整本书可达百万字级）的拼接与统计按需缓存，禁止在 body 每帧重算
    @State private var bookTextCache = ""
    @State private var sourceCount = 0

    private var sourceText: String {
        switch kind {
        case .paste: return pastedText
        case .file: return importedText
        case .book: return bookTextCache
        }
    }

    private var charCount: Int { sourceCount }
    private var canStart: Bool { charCount >= 1_000 && !vm.isFailed && vm.phase != .done }

    var body: some View {
        CompatNavigationView {
            Form {
                if vm.phase == .idle || vm.isFailed {
                    if let resume = cachedResume {
                        resumeSection(resume)
                    }
                    sourceSection
                    if let target = augmentTarget {
                        Section {
                            Label("追加模式：将为档案「\(target.name)」合并新样本——层字段以新样本为准，标签与规则取并集，示范对照替换为新样本产物，全部变化记入修正日志。", systemImage: "arrow.triangle.merge")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if vm.isFailed {
                        Section {
                            Label(vm.phaseLabel, systemImage: "xmark.octagon.fill")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    startSection
                } else {
                    progressSection
                }
            }
            .navigationTitle(augmentTarget == nil ? "蒸馏文风档案" : "追加样本蒸馏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.phase == .idle || vm.isFailed ? "取消" : "停止") {
                        if vm.phase == .idle || vm.isFailed { dismiss() } else { vm.cancel() }
                    }
                }
            }
            .onAppear {
                if cachedResume == nil { cachedResume = StyleDistillCache.load() }
                refreshSourceStats()
            }
            .onChange(of: kind) { _ in refreshSourceStats() }
            .onChange(of: selectedBookID) { _ in refreshSourceStats() }
            .onChange(of: pastedText) { _ in refreshSourceStats() }
            .onChange(of: importedText) { _ in refreshSourceStats() }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .utf8PlainText]) { result in
            if case .success(let url) = result { loadFile(url) }
        }
    }

    // MARK: 样本统计（按需刷新，不在 body 每帧重算）

    private func refreshSourceStats() {
        if kind == .book {
            // 拼接全书正文只在此处发生（切换书目时一次），不随渲染重复
            if let id = selectedBookID,
               let novel = store.novels.first(where: { $0.id == id }) {
                bookTextCache = novel.sortedVolumes
                    .flatMap { $0.sortedChapters.map(\.content) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")
            } else {
                bookTextCache = ""
            }
        }
        sourceCount = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    // MARK: 恢复上次会话

    private func resumeSection(_ resume: StyleDistillCache.Payload) -> some View {
        Section("检测到上次未完成的蒸馏") {
            VStack(alignment: .leading, spacing: 6) {
                Text("来源：\(resume.sourceNote.isEmpty ? "（未填写）" : resume.sourceNote)")
                    .font(.subheadline)
                Text("样本 \(resume.sourceText.count) 字 · 机制分析已完成，可直接从风格卡阶段继续")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        guard let provider = store.defaultProvider else { return }
                        vm.run(sourceText: resume.sourceText,
                               sourceNote: resume.sourceNote,
                               provider: provider,
                               cachedAnalysisRaw: resume.analysisRaw)
                        cachedResume = nil
                    } label: {
                        Label("恢复蒸馏", systemImage: "arrow.clockwise.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button(role: .destructive) {
                        StyleDistillCache.remove()
                        cachedResume = nil
                    } label: {
                        Text("放弃")
                    }
                }
            }
        }
    }

    // MARK: 来源选择

    private var sourceSection: some View {
        Section("样本来源") {
            Picker("方式", selection: $kind) {
                ForEach(SourceKind.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            switch kind {
            case .paste:
                MultilineField(text: $pastedText, placeholder: "粘贴样章正文…（含「第X章」标记的长篇会自动按章节抽样：首尾与中段共 6-10 章）", minHeight: 140)
            case .file:
                Button {
                    showImporter = true
                } label: {
                    Label(importedText.isEmpty ? "选择 .txt 文件" : "已导入 \(importedText.count) 字（点按重选）", systemImage: "doc.badge.plus")
                }
            case .book:
                Picker("选择作品", selection: $selectedBookID) {
                    Text("（请选择）").tag(UUID?.none)
                    ForEach(store.novels) { novel in
                        Text(novel.title).tag(UUID?.some(novel.id))
                    }
                }
            }

            TextField("来源说明（可选，如《作品名》前三十章）", text: $sourceNote)
            HStack {
                Text("样本字数：\(charCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if charCount < 1_000 {
                    Text("至少需要 1000 字")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }

            Section {
                Label("请确保你拥有样本的使用与分析权利。蒸馏只提取抽象文风机制（句法/节奏/词汇/对白等），不会复制情节、人物或设定；全本字数统计用于客观锚点，LLM 只阅读抽样章节。", systemImage: "checkmark.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var startSection: some View {
        Section {
            Button {
                guard let provider = store.defaultProvider else { return }
                vm.run(sourceText: sourceText,
                       sourceNote: sourceNote.trimmingCharacters(in: .whitespacesAndNewlines),
                       provider: provider)
            } label: {
                Text(store.defaultProvider == nil ? "先到设置中配置模型" : "开始蒸馏")
            }
            .disabled(!canStart || store.defaultProvider == nil)
        }
    }

    private var progressSection: some View {
        Section("蒸馏进度") {
            StreamingStatusView(tracker: vm.progress)
            Text(vm.phaseLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if vm.phase == .done, let profile = vm.result {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.headline)
                    if !profile.tags.isEmpty {
                        Text(profile.tags.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !saved {
                        Button("保存并关闭") {
                            store.upsertStyleProfile(profile)
                            saved = true
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    // MARK: 文件导入（iOS 15：fileImporter + 安全作用域读取）

    private func loadFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        importedText = text
        if sourceNote.isEmpty { sourceNote = url.deletingPathExtension().lastPathComponent }
    }
}
#endif

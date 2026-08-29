#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import ZhiMingCore

/// 蒸馏向导：来源（粘贴/导入文件/书库选书）→ 分阶段进度 → 完成自动入库
struct StyleDistillSheet: View {
    private enum SourceKind: String, CaseIterable, Identifiable {
        case paste = "粘贴"
        case file = "导入文件"
        case book = "书库选书"
        var id: String { rawValue }
    }

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

    private var bookText: String {
        guard let id = selectedBookID,
              let novel = store.novels.first(where: { $0.id == id }) else { return "" }
        return novel.sortedVolumes
            .flatMap { $0.sortedChapters.map(\.content) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private var sourceText: String {
        switch kind {
        case .paste: return pastedText
        case .file: return importedText
        case .book: return bookText
        }
    }

    private var charCount: Int { sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var canStart: Bool { charCount >= 1_000 && !vm.isFailed && vm.phase != .done }

    var body: some View {
        CompatNavigationView {
            Form {
                if vm.phase == .idle || vm.isFailed {
                    sourceSection
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
            .navigationTitle("蒸馏文风档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.phase == .idle || vm.isFailed ? "取消" : "停止") {
                        if vm.phase == .idle || vm.isFailed { dismiss() } else { vm.cancel() }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .utf8PlainText]) { result in
            if case .success(let url) = result { loadFile(url) }
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
                MultilineField(text: $pastedText, placeholder: "粘贴样章正文…（建议 3000-50000 字，越多越准）", minHeight: 140)
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
                Label("请确保你拥有样本的使用与分析权利。蒸馏只提取抽象文风机制（句法/节奏/词汇/对白等），不会复制情节、人物或设定。", systemImage: "checkmark.shield")
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

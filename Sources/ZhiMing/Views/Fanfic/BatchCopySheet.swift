#if os(iOS) || os(macOS)
import SwiftUI
import UIKit
import ZhiMingCore

/// 批量复制分析：把最烧 token 的 Map 阶段外包给免费外部 AI App（DeepSeek App / Gemini 等）。
/// 织命生成「系统指令 + 每批章节正文」的超长提示词 → 用户复制去外部 AI 分析 →
/// 拿回逐章 JSON 粘贴回本页 → App 落库并给出下一批 → 全部完成后在织命内归并。
struct BatchCopySheet: View {
    let text: String
    let bookTitle: String
    let store: AppStore
    /// 续写模式：归并走深度归并并写原文边车
    private let continuation: Bool
    /// 续写归并完成回调（续写导入页建书用；普通通道为 nil）
    private let onProfileReady: ((SourceNovelProfile) -> Void)?
    @Environment(\.dismiss) private var dismiss

    /// 归并专用 VM（presetProfileID 复用批量落库的断点键）
    @StateObject private var vm: SourceScanViewModel

    /// 章节正文块（按章合并，断点键 = 章序）
    private var blocks: [(index: Int, body: String)] = []
    /// 固定断点键：批量粘贴落库与最终归并共用
    private let pid: UUID

    @State private var batchSize = 20
    @State private var pasted = ""
    @State private var donePositions: Set<Int> = []
    @State private var copiedTip = false
    @State private var parseError: String?
    @State private var merging = false

    private let batchOptions = [5, 10, 20, 30, 50]

    init(text: String, bookTitle: String, store: AppStore,
         continuation: Bool = false, onProfileReady: ((SourceNovelProfile) -> Void)? = nil) {
        self.text = text
        self.bookTitle = bookTitle
        self.store = store
        self.continuation = continuation
        self.onProfileReady = onProfileReady
        let chunks = SourceScanChunker.chunks(from: text, mode: .full)
        // 同章多块合并为一段（分析覆盖整章；缓存按 chunks 的 pos 分别标记 done）
        var order: [Int] = []
        var merged: [Int: String] = [:]
        for chunk in chunks {
            if merged[chunk.chapterIndex] == nil { order.append(chunk.chapterIndex) }
            let added = (merged[chunk.chapterIndex] ?? "") + (merged[chunk.chapterIndex] == nil ? "" : "\n\n") + chunk.text
            merged[chunk.chapterIndex] = added
        }
        blocks = order.map { (index: $0 + 1, body: merged[$0] ?? "") }   // 1-based 章号
        pid = UUID()
        let provider = store.defaultProvider
            ?? ProviderConfig(name: "未配置", baseUrl: "https://example.com/v1", modelName: "")
        _vm = StateObject(wrappedValue: SourceScanViewModel(provider: provider, store: store))
        vmPreset = pid
    }

    /// 存给 StateObject 初始化的固定键
    private let vmPreset: UUID

    private var totalBlocks: Int { blocks.count }
    private var doneCount: Int { donePositions.count }
    private var allDone: Bool { totalBlocks > 0 && doneCount >= totalBlocks }

    /// 第一批未完成块的下标（0-based blocks 序）
    private var nextBatchRange: Range<Int> {
        let start = donePositions.count
        return start..<min(start + batchSize, totalBlocks)
    }

    private var currentPrompt: String {
        let slice = blocks[nextBatchRange]
        return SourceBatchHelper.prompt(title: bookTitle,
                                        chapters: slice.map { (index: $0.index, title: nil, body: $0.body) })
    }

    var body: some View {
        CompatNavigationView {
            Group {
                if merging {
                    SourceScanProgressSheet(vm: vm) { profile in
                        if let profile { onProfileReady?(profile) }
                        dismiss()
                    }
                } else {
                    mainForm
                }
            }
            .navigationTitle("批量复制分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(allDone ? "关闭" : "取消") { dismiss() }
                }
            }
        }
        .onAppear(perform: reloadDone)
    }

    // MARK: 主表单

    private var mainForm: some View {
        Form {
            Section(footer: Text("这样可以把最烧 token 的逐章提取放在免费的 AI 里做（如 DeepSeek App 免费聊天），织命只做最后的归并。")) {
                Label("原理：复制提示词 → 去外部 AI 粘贴并让它按给出的 JSON 格式逐章分析 → 把它的输出粘贴回来 → 自动进行下一批", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("批次设置") {
                Picker("每批章节数", selection: $batchSize) {
                    ForEach(batchOptions, id: \.self) { n in
                        Text("\(n) 章").tag(n)
                    }
                }
                Text("建议：Gemini 用 5；最小 10（特殊情况可从 5 起步）；DeepSeek Pro 约 20；DeepSeek App Flash 可用 30~50（每批正文越长越容易超上下文，请按实际输入限制调整）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !allDone {
                Section {
                    HStack {
                        Text("进度 \(doneCount)/\(totalBlocks) 章")
                            .font(.subheadline.monospacedDigit())
                        Spacer()
                        if copiedTip {
                            Text("已复制 ✓")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Button {
                        copyPrompt()
                    } label: {
                        Label(copiedTip ? "重新复制本批" : "复制第 \(nextBatchRange.lowerBound + 1) 批提示词",
                              systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    Text("覆盖章节 \(nextRangeLabel)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Section(footer: Text("把外部 AI 输出的全部 JSON 原样粘贴到下面（可包含多余说明文字，App 会自动提取）。")) {
                    MultilineField(text: $pasted, placeholder: "粘贴外部 AI 的分析结果…", minHeight: 140)
                    if let err = parseError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Button("提交本批") {
                        submitBatch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Section("全部完成 🎉") {
                    Label("已收集全部 \(totalBlocks) 章的微摘要。", systemImage: "checkmark.seal.fill")
                    if store.defaultProvider == nil {
                        Text("下一步归并需要模型接口：请先到「设置 → 模型服务」配置一个 Provider。")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Button {
                        startMerge()
                    } label: {
                        Label("开始归并（织命内生成档案）", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.defaultProvider == nil)
                }
            }
        }
    }

    private var nextRangeLabel: String {
        let start = donePositions.count
        let end = min(start + batchSize, totalBlocks)
        let a = blocks[start].index
        let b = blocks[end - 1].index
        return "第 \(a)-\(b) 章"
    }

    // MARK: 动作

    private func reloadDone() {
        donePositions = SourceScanCache.doneIndexes(profile: pid)
    }

    private func copyPrompt() {
        let prompt = currentPrompt
        UIPasteboard.general.string = prompt
        withAnimation { copiedTip = false }
        copiedTip = true
    }

    private func submitBatch() {
        copiedTip = false
        guard let parsed = try? SourceBatchHelper.parseBatchOutput(pasted) else {
            parseError = "未能从粘贴内容中解析出 JSON 微摘要。请确认外部 AI 是按提示词给出的格式输出的。"
            return
        }
        // 落库：chapter(1-based) - 1 → chunks pos（同章多块共用一份摘要）
        let chunks = SourceScanChunker.chunks(from: text, mode: .full)
        var marked = 0
        for (zeroBased, summary) in parsed {
            let payload = (try? String(data: JSONEncoder().encode(summary), encoding: .utf8)) ?? nil
            for (pos, chunk) in chunks.enumerated() where chunk.chapterIndex == zeroBased {
                SourceScanCache.mark(profile: pid, idx: pos, status: "done", payload: payload)
                marked += 1
            }
        }
        parseError = nil
        pasted = ""
        reloadDone()
    }

    private func startMerge() {
        vm.presetProfileID = pid
        merging = true
        vm.start(graphText: text, title: bookTitle, mode: .full, continuation: continuation)
    }
}
#endif
#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 自动撰写流水线面板：门槛校验（全书细纲就绪）→ 每章字数 → 运行进度与已完清单。
/// 风险内联提示：自动撰写不保证效果，建议一章一章边写边看。
struct AutoWriteSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let novel: Novel

    @StateObject private var vm = AutoWriteViewModel()
    @AppStorage("writing.antiai.inline") private var antiAIInline = false
    @State private var wordTarget = 2000
    @State private var missingOutlines = 0

    private let wordOptions = [1000, 1500, 2000, 2500, 3000]
    private var gateReady: Bool { missingOutlines == 0 }

    var body: some View {
        CompatNavigationView {
            Form {
                if vm.isRunning {
                    runningSection
                } else if case .failed(let message) = vm.phase {
                    Section {
                        Label(message, systemImage: "xmark.octagon.fill")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    resultSection
                } else if vm.phase == .done || vm.phase == .stopped {
                    resultSection
                } else {
                    configSection
                }
            }
            .navigationTitle("自动撰写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.isRunning ? "停止" : "关闭") {
                        if vm.isRunning { vm.stop() } else { dismiss() }
                    }
                }
            }
            .onAppear {
                missingOutlines = novel.allChaptersInOrder.filter {
                    ($0.detailedOutline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
            }
        }
    }

    // MARK: 配置（未开跑）

    private var configSection: some View {
        Group {
            Section("门槛检查") {
                if gateReady {
                    Label("细纲已全部生成（\(novel.allChaptersInOrder.count) 章）", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Label("还有 \(missingOutlines) 章未生成细纲，请先在大纲页补齐", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                let pending = AutoWriteViewModel.pendingChapters(in: novel).count
                if pending > 0 {
                    LabeledRowAuto(label: "待写空白章", value: "\(pending) 章（从第一个未写章起顺序补齐）")
                }
            }
            Section("每章字数") {
                Picker("目标字数", selection: $wordTarget) {
                    ForEach(wordOptions, id: \.self) { option in
                        Text("约 \(option) 字").tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle(isOn: $antiAIInline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("去AI味 · 自动")
                        Text("每章撰写时同步注入反模板规则")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Label("自动撰写不保证效果，建议一章一章边写边看。已完成的章节会即时保存，随时可停止后在编辑器修改。", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
            startSection
        }
    }

    private var startSection: some View {
        Section {
            Button {
                guard let provider = store.defaultProvider else { return }
                vm.start(store: store, novel: novel, provider: provider,
                         wordTarget: wordTarget, antiAIInline: antiAIInline)
            } label: {
                Text(store.defaultProvider == nil ? "先到设置中配置模型" : "开始自动撰写")
            }
            .disabled(!gateReady || store.defaultProvider == nil)
        }
    }

    // MARK: 运行中

    private var runningSection: some View {
        Section("运行中") {
            StreamingStatusView(tracker: vm.progress)
            Text(vm.statusLabel)
                .font(.subheadline)
            ProgressView(value: Double(vm.doneCount), total: Double(max(vm.totalTarget, 1)))
                .tint(.accentColor)
            Text("进度 \(vm.doneCount)/\(vm.totalTarget)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                vm.stop()
            } label: {
                Label("停止撰写（已完成章节即时保存）", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 结果（完成/停止/失败后的清单与重新开始）

    private var resultSection: some View {
        Group {
            Section("结果") {
                Text(vm.statusLabel)
                    .font(.subheadline)
                if vm.phase == .done {
                    Label("全部章节已写完并建档", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundColor(.green)
                }
                ForEach(vm.completedTitles, id: \.self) { title in
                    Label(title, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            configSection
        }
    }
}

private struct LabeledRowAuto: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
#endif

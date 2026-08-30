#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 同人原作分析进度：阶段标签 + 块进度 + token 计量 + 流式状态 + 暂停/继续。
struct SourceScanProgressSheet: View {
    @ObservedObject var vm: SourceScanViewModel
    var onFinish: (SourceNovelProfile?) -> Void

    private var currentStage: String {
        switch vm.phase {
        case .splitting: return "解析"
        case .mapping: return "提取"
        case .reducing: return "归并"
        case .done: return "完成"
        default: return "解析"
        }
    }

    private let stageNames = ["解析", "提取", "归并", "完成"]

    var body: some View {
        CompatNavigationView {
            VStack(alignment: .leading, spacing: AppTheme.spacing[3]) {
                stageCapsules
                StreamingStatusView(tracker: vm.progress)
                blockProgress
                tokenMeter
                if case .failed(let message) = vm.phase {
                    Label(message, systemImage: "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if vm.phase == .done {
                    completionCard
                }
                Spacer(minLength: 0)
                actionBar
            }
            .padding(AppTheme.spacing[3])
            .navigationTitle("分析进度")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: 阶段标签行

    private var stageCapsules: some View {
        HStack(spacing: AppTheme.spacing[1]) {
            ForEach(stageNames, id: \.self) { name in
                let active = name == currentStage
                Text(name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(active ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                                in: Capsule())
                    .foregroundStyle(active ? Color.white : Color.secondary)
            }
        }
    }

    private var blockProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(vm.doneChunks), total: Double(max(vm.totalChunks, 1)))
            Text("块进度 \(vm.doneChunks)/\(vm.totalChunks)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var tokenMeter: some View {
        Text("token 输入 \(vm.tokensIn / 1000)k / 输出 \(vm.tokensOut / 1000)k / 预算 2000k")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("档案已生成", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
            if let profile = vm.resultProfile {
                Text(profile.title)
                    .font(.headline)
                Text("人物 \(profile.characters.count) · 事件 \(profile.timeline.count) · 设定 \(profile.worldbuilding.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacing[3])
        .zmCard(padding: 0)
    }

    private var actionBar: some View {
        HStack {
            if vm.phase == .paused {
                Button {
                    vm.resume()
                } label: {
                    Label("继续", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
            } else if vm.phase != .done && !vm.isFailed {
                Button {
                    vm.cancel()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if vm.phase == .done {
                Button("完成") {
                    onFinish(vm.resultProfile)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
#endif
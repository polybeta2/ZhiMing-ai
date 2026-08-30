#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 同人原作分析进度：GIF 祈愿 + 阶段标签 + 块进度 + token 计量 + 流式状态 + 暂停/继续 + 服务商切换。
struct SourceScanProgressSheet: View {
    @ObservedObject var vm: SourceScanViewModel
    var onFinish: (SourceNovelProfile?) -> Void

    /// 服务商选择（进行中禁用；@State 与 vm.provider 同步展示）
    @State private var providerID: UUID?

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

    private var isWorking: Bool { vm.phase == .splitting || vm.phase == .mapping || vm.phase == .reducing }

    var body: some View {
        CompatNavigationView {
            VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
                prayingHeader
                stageCapsules
                StreamingStatusView(tracker: vm.progress)
                blockProgress
                if vm.phase == .mapping && vm.estimatedRemainingSeconds > 0 {
                    remainingEstimate
                }
                tokenMeter
                if vm.phase == .paused || vm.isFailed {
                    providerPicker
                }
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
            .onAppear {
                if providerID == nil { providerID = vm.provider.id }
            }
        }
    }

    /// 祈愿头图：本地 GIF（少女祈祷中）+ 文案，扫描期间展示
    private var prayingHeader: some View {
        VStack(spacing: AppTheme.spacing[1]) {
            AnimatedGIFView(resourceName: "praying")
                .frame(width: 110, height: 110)
            Text(isWorking ? "少女祈祷中..." : "少女静静等着…")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppTheme.spacing[0])
    }

    /// 剩余时间估算：平均秒/章 × 剩余块数（随进度滚动）
    private var remainingEstimate: some View {
        let secs = vm.estimatedRemainingSeconds
        let text: String
        if secs >= 3600 {
            text = String(format: "%d 小时 %02d 分", secs / 3600, (secs % 3600) / 60)
        } else if secs >= 60 {
            text = String(format: "%d 分 %02d 秒", secs / 60, secs % 60)
        } else {
            text = "\(secs) 秒"
        }
        return HStack(spacing: 6) {
            Image(systemName: "clock")
            Text("预计剩余 \(text)（平均 \(String(format: "%.1f", vm.avgSecondsPerChunk)) 秒/章）")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    /// 服务商切换（暂停/失败后可换，已保存的服务商列表）
    private var providerPicker: some View {
        let providers = vm.availableProviders
        return VStack(alignment: .leading, spacing: 4) {
            Text("API 服务商")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("API 服务商", selection: Binding(
                get: { providerID ?? vm.provider.id },
                set: { newID in
                    providerID = newID
                    if let p = providers.first(where: { $0.id == newID }) {
                        vm.setProvider(p)
                    }
                }
            )) {
                ForEach(providers) { p in
                    Text(p.name).tag(p.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(providers.isEmpty || isWorking)
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
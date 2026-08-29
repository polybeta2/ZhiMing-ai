#if canImport(SwiftUI)
import SwiftUI

/// 流式生成状态行：等待首Token / 深度思考（不显示思维链原文）/ 正在输出
/// `showsOutputting`：JSON 等静默场景传 true（输出期间只显示统计）；
/// 正文流式场景传 false（输出阶段正常显示文本，本视图隐藏）
struct StreamingStatusView: View {
    @ObservedObject var tracker: StreamProgressTracker
    var showsOutputting = true

    private var statusText: String? {
        switch tracker.stage {
        case .waitingFirstToken:
            return "正在等待首Token \(tracker.elapsedString)s"
        case .thinking:
            return "深度思考 \(tracker.reasoningChars)字 \(tracker.elapsedString)s"
        case .outputting:
            return showsOutputting ? "正在输出 \(tracker.contentChars)字 \(tracker.elapsedString)s" : nil
        case .idle:
            return nil
        }
    }

    var body: some View {
        if let text = statusText {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(text)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color(uiColor: .separator).opacity(0.25), lineWidth: 0.5)
            )
        }
    }
}

extension StreamProgressTracker {
    /// 一位小数的阶段耗时
    var elapsedString: String { String(format: "%.1f", elapsed) }
}
#endif

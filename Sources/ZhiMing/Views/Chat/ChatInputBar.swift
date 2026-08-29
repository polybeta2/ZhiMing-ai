#if canImport(SwiftUI)
import SwiftUI

/// 多行输入 + 发送/停止（流式中发送键变停止键），iMessage 式胶囊输入框
/// iOS 15 兼容：无 TextField(axis:)，使用单行输入（多行长文本场景由 MultilineField 承担）
struct ChatInputBar: View {
    @Binding var text: String
    var isStreaming = false
    var placeholder = "输入消息…"
    var onSend: () -> Void
    var onStop: () -> Void

    private var canSend: Bool {
        isStreaming || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacing[1]) {
            HStack(spacing: AppTheme.spacing[1]) {
                TextField(placeholder, text: $text)
            }
            .padding(.horizontal, AppTheme.spacing[3])
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusCapsule)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusCapsule)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            )

            Button {
                if isStreaming {
                    onStop()
                } else {
                    ZMHaptics.impact(.medium)
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isStreaming ? .red : (canSend ? .accentColor : Color(uiColor: .tertiaryLabel)))
            }
            .buttonStyle(.zmPress)
            .disabled(!canSend)
            .animation(AppTheme.Spring.press, value: isStreaming)
        }
        .padding(.horizontal, AppTheme.spacing[2])
        .padding(.vertical, AppTheme.spacing[1])
        .background(.bar)
    }
}
#endif

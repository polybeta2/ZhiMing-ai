import SwiftUI

/// 多行输入 + 发送/停止（流式中发送键变停止键），圆角 28 胶囊输入框
/// iOS 15 兼容：无 TextField(axis:)，使用单行输入（多行长文本场景由 MultilineField 承担）
struct ChatInputBar: View {
    @Binding var text: String
    var isStreaming = false
    var placeholder = "输入消息…"
    var onSend: () -> Void
    var onStop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacing[1]) {
            TextField(placeholder, text: $text)
                .padding(.horizontal, AppTheme.spacing[3])
                .padding(.vertical, AppTheme.spacing[1] + 2)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCapsule))

            Button {
                if isStreaming {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isStreaming ? .red : .accentColor)
            }
            .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppTheme.spacing[2])
        .padding(.vertical, AppTheme.spacing[1])
        .background(.bar)
    }
}

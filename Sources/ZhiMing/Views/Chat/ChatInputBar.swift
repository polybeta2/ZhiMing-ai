import SwiftUI

/// 多行输入 + 发送/停止（流式中发送键变停止键），圆角 28 胶囊输入框
struct ChatInputBar: View {
    @Binding var text: String
    var isStreaming = false
    var placeholder = "输入消息…"
    var onSend: () -> Void
    var onStop: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacing[1]) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
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
                    .foregroundStyle(isStreaming ? Color.red : Color.accentColor)
            }
            .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppTheme.spacing[2])
        .padding(.vertical, AppTheme.spacing[1])
        .background(.bar)
    }
}

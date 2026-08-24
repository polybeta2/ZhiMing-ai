import SwiftUI

/// 消息气泡 + 流式光标 + Markdown 轻量渲染（AttributedString）
/// 用户：右对齐强调色气泡；AI：左对齐毛玻璃材质气泡
struct MessageBubbleView: View {
    let role: String                     // user / assistant
    let text: String
    var isStreaming = false

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
                renderedText
                    .padding(.horizontal, AppTheme.spacing[2])
                    .padding(.vertical, AppTheme.spacing[1] + 2)
                    .background { bubbleBackground }
                    .textSelection(.enabled)
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var renderedText: some View {
        if isStreaming && text.isEmpty {
            typingDots
                .padding(.vertical, AppTheme.spacing[1])
        } else if isStreaming {
            // 性能关键：流式期间渲染纯文本，避免对不断变长的内容反复做 Markdown 解析（O(n²) 卡顿源）
            Text(text)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .modifier(StreamingCursorModifier(active: true))
        } else if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .foregroundStyle(isUser ? Color.white : Color.primary)
        } else {
            Text(text)
                .foregroundStyle(isUser ? Color.white : Color.primary)
        }
    }

    /// 流式开始前的三点动效
    private var typingDots: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 6, height: 6)
                        .opacity(0.25 + 0.75 * max(0, sin(t * 4 - Double(index) * 0.9)))
                }
            }
            .frame(minWidth: 40)
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            RoundedRectangle(cornerRadius: AppTheme.radiusBubble)
                .fill(.tint.opacity(0.85))
        } else {
            RoundedRectangle(cornerRadius: AppTheme.radiusBubble)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radiusBubble)
                        .fill(Color(uiColor: .systemBackground).opacity(AppTheme.bubbleMaterialOpacity * 0.35))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radiusBubble)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
        }
    }
}

/// 流式输出时在气泡末尾跟随一个光标
private struct StreamingCursorModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            HStack(alignment: .bottom, spacing: 1) {
                content
                Text("▍")
                    .foregroundStyle(.tint)
            }
        } else {
            content
        }
    }
}

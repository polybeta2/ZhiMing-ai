#if canImport(SwiftUI)
import SwiftUI

/// 消息气泡 + 流式光标 + Markdown 轻量渲染（AttributedString）
/// 用户：右对齐强调色气泡（暗色模式降透明度防刺眼）；AI：左对齐实心卡片气泡
struct MessageBubbleView: View {
    let role: String                     // user / assistant
    let text: String
    var isStreaming = false
    @Environment(\.colorScheme) private var scheme

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
        let shape = BubbleShape(isUser: isUser)
        if isUser {
            // iMessage 惯例：强调色实心渐变气泡，尾侧小圆角
            // 暗色模式降低不透明度（黑色底透出即等效变暗），避免大面积高饱和刺眼
            let top = scheme == .dark ? Color.accentColor.opacity(0.72) : Color.accentColor
            let bottom = scheme == .dark ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.82)
            shape
                .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.accentColor.opacity(scheme == .dark ? 0.18 : 0.28), radius: 6, x: 0, y: 3)
        } else {
            // 不叠淡色毛玻璃：实心次级背景 + 发丝描边，保证任何底色上可读
            shape
                .fill(Color(uiColor: .systemBackground))
                .overlay {
                    shape.stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
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
#endif

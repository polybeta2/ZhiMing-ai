#if canImport(SwiftUI)
import SwiftUI
import UIKit

// MARK: - iOS 15 兼容层
// 本项目部署目标为 iOS 15；此处集中提供高版本 SwiftUI API 的降级等价物。

/// ContentUnavailableView 的 iOS 15 等价物
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String = ""

    var body: some View {
        VStack(spacing: AppTheme.spacing[2]) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacing[4])
    }
}

/// 自适应多行输入：统一走 UITextView 自增高内核（iOS 15 / 16 / 26 行为一致，
/// 规避 TextField(axis:.vertical) 在 iOS 26 空态占满整屏、fixedSize 后无法点击的问题）。
/// - minHeight：空态最小高度；maxLines：封顶行数（超出内部滚动）
/// - fixedHeight：固定高度模式（立项表单等容器敏感场景），内容超出时内部滚动
/// - textStyle：文本样式（统一生效，不再依赖外部 .font 修饰）
struct MultilineField: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 66
    var maxLines: Int? = nil
    var fixedHeight: CGFloat? = nil
    /// 空态保底行数（如助手输入条空态 2 行），按实际字体行高换算
    var minLines: Int? = nil
    /// 固定高度模式（按行）：如 fixedLines=2 表示固定 2 行高、内容超出内部滚动。
    /// 对齐 fixedHeight，但随动态字体缩放；二者任一非空即进入固定高度模式
    var fixedLines: Int? = nil
    var textStyle: UIFont.TextStyle = .body

    var body: some View {
        let uiFont = UIFont.preferredFont(forTextStyle: textStyle)
        let effectiveMin = minLines.map { max(minHeight, uiFont.lineHeight * CGFloat($0)) } ?? minHeight
        let effectiveFixed = fixedLines.map { uiFont.lineHeight * CGFloat($0) } ?? fixedHeight
        return ZStack(alignment: .topLeading) {
            GrowingTextView(
                text: $text,
                textStyle: textStyle,
                minHeight: effectiveMin,
                maxLines: maxLines,
                fixedHeight: effectiveFixed
            )
            if text.isEmpty {
                Text(placeholder)
                    .font(Font.system(size: uiFont.pointSize))
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// UITextView 自增高内核：内容多高框就多高，超过 maxLines（或固定高度模式）封顶开启内部滚动
private struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    var textStyle: UIFont.TextStyle
    var minHeight: CGFloat
    var maxLines: Int?
    var fixedHeight: CGFloat?

    func makeUIView(context: Context) -> GrowingUITextView {
        let tv = GrowingUITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = false
        tv.font = UIFont.preferredFont(forTextStyle: textStyle)
        tv.textColor = .label
        return tv
    }

    func updateUIView(_ tv: GrowingUITextView, context: Context) {
        // 拼音等 IME 组合期间（markedTextRange 非空）不用绑定反向覆盖，避免打断输入
        if tv.markedTextRange == nil, tv.text != text {
            let selection = tv.selectedTextRange
            tv.text = text
            if let selection { tv.selectedTextRange = selection }
        }
        let font = UIFont.preferredFont(forTextStyle: textStyle)
        if tv.font != font { tv.font = font }
        if tv.minHeight != minHeight { tv.minHeight = minHeight }
        if tv.maxLines != maxLines { tv.maxLines = maxLines }
        if tv.fixedHeight != fixedHeight { tv.fixedHeight = fixedHeight }
        tv.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            tv.invalidateIntrinsicContentSize()
        }
    }
}

private final class GrowingUITextView: UITextView {
    var minHeight: CGFloat = 0
    var maxLines: Int?
    var fixedHeight: CGFloat?

    private var lastWidth: CGFloat = 0

    private var contentHeight: CGFloat {
        // 布局首帧宽度尚未就绪时 sizeThatFits(width:0) 会把每个字折成一行算出爆表高度，
        // 导致输入框首帧撑满整屏；宽度就绪前以最小高度兜底
        guard bounds.width > 1 else { return minHeight }
        return sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
    }

    private var capHeight: CGFloat? {
        guard let maxLines else { return nil }
        let lineHeight = font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        return lineHeight * CGFloat(maxLines)
    }

    override var intrinsicContentSize: CGSize {
        if let fixed = fixedHeight {
            // 固定高度模式：高度锁定，内容溢出靠内部滚动
            return CGSize(width: UIView.noIntrinsicMetric, height: fixed)
        }
        var height = max(contentHeight, minHeight)
        if let cap = capHeight, height > cap { height = cap }
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 宽度变化（旋转/布局）后内容测量失效，重新触发尺寸协商
        if bounds.width != lastWidth {
            lastWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        // 固定高度或封顶后允许内部滚动；否则保持不滚，让外层页面接管
        let wantsScroll: Bool
        if fixedHeight != nil {
            wantsScroll = true
        } else {
            wantsScroll = (capHeight.map { contentHeight > $0 }) ?? false
        }
        if isScrollEnabled != wantsScroll {
            isScrollEnabled = wantsScroll
            invalidateIntrinsicContentSize()
        }
    }
}

extension View {
    /// 两参 onChange 的单参兼容版（语义：拿到新值）
    func zmOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        onChange(of: value) { newValue in action(newValue) }
    }
}

/// alert 内嵌 TextField（iOS 16+）的 iOS 15 等价物：轻量重命名 sheet
struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let placeholder: String
    let initialText: String
    let onSave: (String) -> Void

    @State private var text: String = ""

    init(title: String, placeholder: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(text.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// 可直接编辑的数值输入行：数字输入框 + 加减快捷键；输入实时夹紧到范围
struct NumberFieldRow: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            Text(label)
            Spacer()
            Button {
                set(value - step)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 96)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .zmOnChange(of: text) { newValue in
                    let digits = newValue.filter { $0.isNumber }
                    if let parsed = Int(digits) {
                        value = min(max(parsed, range.lowerBound), range.upperBound)
                    }
                }
                .onAppear { text = String(value) }

            Button {
                set(value + step)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    private func set(_ target: Int) {
        let clamped = min(max(target, range.lowerBound), range.upperBound)
        value = clamped
        text = String(clamped)
    }
}

/// NavigationStack 的 iOS 15 兼容包装：16+ 走 NavigationStack，15 走单栏 NavigationView
struct CompatNavigationView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

// MARK: - 内联确认卡（替代系统弹窗）
// 部分系统版本上 .alert 的按钮 action 闭包不可靠（确认后状态写入被丢弃，
// 表现为「确认没反应、再点又弹窗」），关键确认一律改用普通视图按钮。

struct InlineConfirmCard: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let onCancel {
                    Button("取消", action: onCancel)
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(action: onConfirm) {
                    Text(confirmLabel).frame(minWidth: 88)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif

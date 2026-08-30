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

/// 自适应多行输入：UITextView 内核 + 高度由 SwiftUI 层显式 frame 锁死。
/// iOS 26/LiveContainer 上桥接层不查询 UITextView 的 intrinsicContentSize（UIScrollView
/// 类视图会被直接拉伸到全部可用空间，即"占满整屏"根因），因此内容高度必须实测回传、
/// 在 SwiftUI 侧用 .frame(height:) 确定，不参与任何桥接尺寸协商。
/// - minHeight：最小高度；maxLines：封顶行数（超出内部滚动）
/// - fixedHeight / fixedLines：固定高度模式（像素 / 按行随动态字体缩放）
/// - minLines：最小高度按行折算
/// - textStyle：文本样式（统一生效）
struct MultilineField: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 66
    var maxLines: Int? = nil
    var fixedHeight: CGFloat? = nil
    var minLines: Int? = nil
    var fixedLines: Int? = nil
    var textStyle: UIFont.TextStyle = .body

    /// UITextView 实测的内容高度（宽度就绪后回传；首帧为 0 → 取最小高度）
    @State private var measuredHeight: CGFloat = 0

    var body: some View {
        let uiFont = UIFont.preferredFont(forTextStyle: textStyle)
        let effectiveMin = minLines.map { max(minHeight, uiFont.lineHeight * CGFloat($0)) } ?? minHeight
        let effectiveFixed = fixedLines.map { uiFont.lineHeight * CGFloat($0) } ?? fixedHeight
        let cap = maxLines.map { uiFont.lineHeight * CGFloat($0) }
        // 最终高度：固定模式恒定；自适应模式 = clamp(实测, 最小, 封顶)
        let targetHeight: CGFloat
        if let fixed = effectiveFixed {
            targetHeight = fixed
        } else if let cap {
            targetHeight = min(max(measuredHeight, effectiveMin), cap)
        } else {
            targetHeight = max(measuredHeight, effectiveMin)
        }
        return GrowingTextView(
            text: $text,
            placeholder: placeholder,
            textStyle: textStyle,
            capHeight: cap,
            fixedHeight: effectiveFixed,
            onMeasure: { h in
                if abs(h - measuredHeight) > 0.5 { measuredHeight = h }
            }
        )
        .frame(height: targetHeight)   // ★ 高度在此锁死，桥接协商失效也无妨
    }
}

/// UITextView 内核：测量内容高度回传 SwiftUI；封顶/固定模式下开启内部滚动。
/// placeholder 为 UIKit 内置 label，直接跟随 UITextView 实际内容隐藏（不依赖 SwiftUI binding 同步）
private struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var textStyle: UIFont.TextStyle
    var capHeight: CGFloat?
    var fixedHeight: CGFloat?
    var onMeasure: (CGFloat) -> Void

    func makeUIView(context: Context) -> GrowingUITextView {
        let tv = GrowingUITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = false
        tv.font = UIFont.preferredFont(forTextStyle: textStyle)
        tv.textColor = .label
        tv.refreshPlaceholder(text: placeholder)
        return tv
    }

    func updateUIView(_ tv: GrowingUITextView, context: Context) {
        tv.onMeasure = onMeasure
        tv.refreshPlaceholder(text: placeholder)
        // 拼音等 IME 组合期间（markedTextRange 非空）不用绑定反向覆盖，避免打断输入
        if tv.markedTextRange == nil, tv.text != text {
            let selection = tv.selectedTextRange
            tv.text = text
            if let selection { tv.selectedTextRange = selection }
        }
        let font = UIFont.preferredFont(forTextStyle: textStyle)
        if tv.font != font {
            tv.font = font
            tv.syncPlaceholderFont(font)
        }
        if tv.capHeight != capHeight { tv.capHeight = capHeight }
        if tv.fixedHeight != fixedHeight { tv.fixedHeight = fixedHeight }
        tv.measureAndReport()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }

        func textViewDidChange(_ tv: GrowingUITextView) {
            parent.text = tv.text
            tv.refreshPlaceholder(text: tv.placeholderText)
            tv.measureAndReport()
        }
    }
}

private final class GrowingUITextView: UITextView {
    var capHeight: CGFloat?
    var fixedHeight: CGFloat?
    var onMeasure: ((CGFloat) -> Void)?

    private var lastWidth: CGFloat = 0

    private(set) var placeholderText: String = ""
    private let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.isHidden = true
        addSubview(placeholderLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 更新 placeholder 文案并跟随实际内容显隐（不依赖 SwiftUI binding）
    func refreshPlaceholder(text: String) {
        placeholderText = text
        placeholderLabel.text = text
        placeholderLabel.isHidden = !self.text.isEmpty
    }

    /// 输入文本与 placeholder 用同一字体（动态字号变化时同步）
    func syncPlaceholderFont(_ font: UIFont) {
        placeholderLabel.font = font
    }

    /// 实测内容高度并回传（宽度未就绪时不测，避免 sizeThatFits(width:0) 爆表）
    func measureAndReport() {
        guard bounds.width > 1 else { return }
        let h = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
        onMeasure?(h)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // placeholder label 与输入文本同起点（textContainerInset=0, lineFragmentPadding=0）
        placeholderLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        // 宽度变化（旋转/布局/字体）后重新测量回传
        if bounds.width != lastWidth {
            lastWidth = bounds.width
            measureAndReport()
        }
        // 固定高度或内容超封顶 → 内部滚动；否则交给外层（frame 已锁死高度，此处仅控制滚动开关）
        let wantsScroll: Bool
        if fixedHeight != nil {
            wantsScroll = true
        } else if let cap = capHeight {
            wantsScroll = sizeThatFits(CGSize(width: max(bounds.width, 1), height: .greatestFiniteMagnitude)).height > cap
        } else {
            wantsScroll = false
        }
        if isScrollEnabled != wantsScroll {
            isScrollEnabled = wantsScroll
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

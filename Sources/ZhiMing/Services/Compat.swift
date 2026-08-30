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

/// 自适应多行输入：SwiftUI 原生 TextEditor + Text 镜像测高 + frame 锁死。
/// iOS 26/LiveContainer 上 UIViewRepresentable 桥接不可靠（delegate 不回调 → binding 不更新、
/// 高度不回传，即"输入不进状态/按钮不可点/高度不变"的根因），故全部改用 SwiftUI 原生设施：
/// - text binding：TextEditor 原生绑定，输入即时生效（发送按钮/placeholder 即时响应）
/// - 高度：镜像 Text（同字体同宽）经 GeometryReader 实测 → .frame(height:) 锁定，
///   内容超出封顶行数后 TextEditor 自动内部滚动
/// - minHeight / minLines / maxLines / fixedHeight / fixedLines 参数语义同前
/// - textStyle：统一折算字体（动态字体可缩放）
struct MultilineField: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 66
    var maxLines: Int? = nil
    var fixedHeight: CGFloat? = nil
    var minLines: Int? = nil
    var fixedLines: Int? = nil
    var textStyle: UIFont.TextStyle = .body

    /// 镜像 Text 实测的内容高度（含模拟内边距）
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let uiFont = UIFont.preferredFont(forTextStyle: textStyle)
        let font = Font.system(size: uiFont.pointSize)
        let lineHeight = uiFont.lineHeight
        let effectiveMin = minLines.map { max(minHeight, lineHeight * CGFloat($0)) } ?? minHeight
        let effectiveFixed = fixedLines.map { lineHeight * CGFloat($0) } ?? fixedHeight
        let cap = maxLines.map { lineHeight * CGFloat($0) }
        // 最终高度：固定模式恒定；自适应模式 = clamp(实测, 最小, 封顶)
        let targetHeight: CGFloat
        if let fixed = effectiveFixed {
            targetHeight = fixed
        } else if let cap {
            targetHeight = min(max(contentHeight, effectiveMin), cap)
        } else {
            targetHeight = max(contentHeight, effectiveMin)
        }

        return ZStack(alignment: .topLeading) {
            // 测量镜像：与 TextEditor 同字体同宽（padding 模拟 TextEditor 内边距），高度即内容所需
            Text(text + " ")
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 5)
                .padding(.vertical, 6)
                .hidden()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentHeight = geo.size.height }
                            .zmOnChange(of: geo.size.height) { contentHeight = $0 }
                    }
                )
            Group {
                if #available(iOS 16.0, *) {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                } else {
                    // iOS 15：保留默认背景（用户未在该版本验证视觉）
                    TextEditor(text: $text)
                }
            }
            .font(font)
            .frame(height: targetHeight)   // ★ 高度在此锁死
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .padding(.leading, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
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

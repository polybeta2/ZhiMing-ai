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

/// TextField(axis: .vertical) 的 iOS 15 等价物：TextEditor 基多行输入
struct MultilineField: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 66

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .scrollContentBackgroundCompat()
        }
    }
}

/// TextEditor 背景清理：iOS 16+ 用 scrollContentBackground，iOS 15 由全局
/// UITextView.appearance().backgroundColor = .clear 兜底（见 ZhiMingApp.init）
extension View {
    @ViewBuilder
    func scrollContentBackgroundCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

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

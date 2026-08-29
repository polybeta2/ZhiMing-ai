#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 模型切换（单选列表；仅当前会话生效）
struct ModelSelectorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 当前会话选中的提供商；nil = 跟随默认
    @Binding var selection: ProviderConfig?

    var body: some View {
        CompatNavigationView {
            List {
                if store.providers.isEmpty {
                    Section {
                        Text("还没有配置模型提供商，请先到「设置 → 模型提供商」添加。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(store.providers) { provider in
                    Button {
                        selection = provider
                        dismiss()
                    } label: {
                        HStack(spacing: AppTheme.spacing[2]) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(provider.name).font(.subheadline.weight(.medium))
                                    if provider.isDefault {
                                        Text("默认")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text(provider.modelName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected(provider) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("切换模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func isSelected(_ provider: ProviderConfig) -> Bool {
        if let selection { return selection.id == provider.id }
        return provider.id == store.defaultProvider?.id
    }
}
#endif

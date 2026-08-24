import SwiftUI

/// 提供商卡片列表（对标 Kelivo 会话列表卡片行）
struct ProviderListView: View {
    @Environment(AppStore.self) private var store
    @State private var editingProvider: ProviderConfig?
    @State private var showNew = false

    var body: some View {
        List {
            if store.providers.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("还没有配置模型提供商")
                            .font(.headline)
                        Text("点击右上角 + 添加任意 OpenAI 兼容接口（OpenAI / DeepSeek / 通义千问 / 本地代理）。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppTheme.spacing[2])
                }
            }
            ForEach(store.providers) { provider in
                Button {
                    editingProvider = provider
                } label: {
                    ProviderRow(provider: provider)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if !provider.isDefault {
                        Button {
                            store.makeDefault(provider)
                        } label: {
                            Label("设为默认", systemImage: "checkmark.seal")
                        }
                    }
                    Button(role: .destructive) {
                        store.deleteProvider(provider)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("模型提供商")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNew) {
            ProviderEditView(provider: nil)
        }
        .sheet(item: $editingProvider) { provider in
            ProviderEditView(provider: provider)
        }
    }
}

private struct ProviderRow: View {
    let provider: ProviderConfig

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: provider.isDefault ? "checkmark.seal.fill" : "cpu")
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.headline)
                    if provider.isDefault {
                        Text("默认")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                Text(provider.modelName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(provider.baseUrl)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, AppTheme.spacing[0])
        .contentShape(Rectangle())
    }
}

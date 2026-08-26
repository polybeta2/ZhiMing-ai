import SwiftUI

/// 提供商卡片列表（对标 Kelivo 会话列表卡片行）
struct ProviderListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingProvider: ProviderConfig?
    @State private var showNew = false
    @State private var deletingProvider: ProviderConfig?

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
                        deletingProvider = provider
                    } label: {
                        Label("删除…", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("模型提供商")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        // 删除是破坏性操作且连带清除 Keychain 密钥：sheet 内嵌确认卡承载写入
        // （v1.5.2 教训：系统弹窗按钮动作在本项目目标系统上不可靠）
        .sheet(item: $deletingProvider) { provider in
            VStack(spacing: AppTheme.spacing[2]) {
                InlineConfirmCard(
                    title: "删除「\(provider.name)」？",
                    message: "将移除该提供商，并删除保存在钥匙串中的 API Key，无法恢复。",
                    confirmLabel: "确认删除",
                    onConfirm: {
                        store.deleteProvider(provider)
                        deletingProvider = nil
                    },
                    onCancel: { deletingProvider = nil }
                )
                Spacer()
            }
            .padding(AppTheme.spacing[3])
        }
    }
}

private struct ProviderRow: View {
    @ObservedObject var provider: ProviderConfig

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            ZStack(alignment: .center) {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: provider.isDefault ? "checkmark.seal.fill" : "cpu")
                    .foregroundStyle(Color.accentColor)
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
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
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

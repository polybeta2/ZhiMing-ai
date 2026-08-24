import SwiftUI

/// 设置页：Kelivo 风格分组卡片（模型与服务 / 外观 / 关于）
struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section("模型与服务") {
                NavigationLink {
                    ProviderListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("模型提供商")
                            if let provider = store.defaultProvider {
                                Text("当前默认：\(provider.name) · \(provider.modelName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("尚未配置，AI 功能不可用")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } icon: {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.tint)
                    }
                }
            }

            Section("外观") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label {
                        HStack {
                            Text("强调色与深色模式")
                            Spacer()
                            Circle()
                                .fill(AppearanceSettings.accentColor)
                                .frame(width: 16, height: 16)
                            Text(AppearanceSettings.schemeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paintpalette")
                            .foregroundStyle(.tint)
                    }
                }
            }

            Section("关于") {
                VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                    HStack(spacing: AppTheme.spacing[2]) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppearanceSettings.accentColor.gradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "text.book.closed.fill")
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("织命").font(.headline)
                            Text("本地优先的 AI 长篇小说写作台")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("版本 1.0.0 · 数据仅保存在本机")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("功能理念参考开源项目「司命 siming-ai」，界面气质参考开源项目 Kelivo。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, AppTheme.spacing[1])
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

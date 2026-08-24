import SwiftUI

/// 设置页：Kelivo 风格分组卡片（模型与服务 / 外观 / 关于）
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section("模型与服务") {
                NavigationLink(destination: ProviderListView()) {
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
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Section("外观") {
                NavigationLink(destination: AppearanceSettingsView()) {
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
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Section("关于") {
                VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                    HStack(spacing: AppTheme.spacing[2]) {
                        ZStack(alignment: .center) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [AppearanceSettings.accentColor, AppearanceSettings.accentColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 44, height: 44)
                            Image(systemName: "text.book.closed.fill")
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("织命").font(.headline)
                            Text("本地优先的 AI 长篇小说写作台")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("版本 1.1.0 · 数据仅保存在本机 · 支持 iOS 15+")
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

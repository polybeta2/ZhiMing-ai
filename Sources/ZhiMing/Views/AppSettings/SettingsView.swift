import SwiftUI

/// 设置页：Kelivo 风格分组卡片（模型与服务 / 外观 / 关于）
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    /// 开发者功能：强提醒确认后才放行（iOS 15 隐藏链接跳转）
    @State private var showDevWarning = false
    @State private var devUnlocked = false

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
                        ZMSettingsIcon(systemName: "server.rack", tint: Color(red: 0.30, green: 0.36, blue: 0.57))
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
                        ZMSettingsIcon(systemName: "paintpalette.fill", tint: .purple)
                    }
                }
            }

            Section(footer: Text(showDevWarning
                                 ? "再次提醒：错误改动内置提示词可能导致生成效果严重下降。点击上方条目确认进入，或点「取消」返回。"
                                 : "内置提示词编辑与示例标签库管理，修改保存后立即生效。")) {
                // 两步点击确认（不用系统弹窗：部分系统版本 alert 按钮动作不可靠）
                Button {
                    if showDevWarning {
                        showDevWarning = false
                        devUnlocked = true
                    } else {
                        withAnimation { showDevWarning = true }
                    }
                } label: {
                    HStack(spacing: AppTheme.spacing[2]) {
                        ZMSettingsIcon(systemName: "wrench.and.screwdriver.fill", tint: showDevWarning ? .red : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(showDevWarning ? "⚠️ 再次点击，确认进入开发者功能" : "开发者功能")
                                .foregroundColor(showDevWarning ? .red : nil)
                            Text(showDevWarning
                                 ? "除非您具备清晰的提示词编写经验，否则请勿擅自修改此处内容，错误改动可能导致生成效果严重下降。"
                                 : "内置提示词编辑与示例标签库管理")
                                .font(.caption)
                                .foregroundStyle(showDevWarning ? Color.red : .secondary)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                if showDevWarning {
                    Button("取消") {
                        withAnimation { showDevWarning = false }
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
                    Text("版本 1.8.3 · 数据仅保存在本机 · 支持 iOS 15+")
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
        .background(devUnlockLink)
    }

    /// 确认后推入开发者面板。
    /// 注意：链接必须常驻视图树（不能用 if 包裹），确认时只翻转 isActive——
    /// iOS 15 下「链接随状态翻转同时插入」不会触发导航，这是此前确认后进不去的根因之一。
    private var devUnlockLink: some View {
        NavigationLink(
            destination: DeveloperPanelView(),
            isActive: $devUnlocked
        ) { EmptyView() }
        .hidden()
    }
}

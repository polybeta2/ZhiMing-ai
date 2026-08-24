import SwiftUI

@main
struct ZhiMingApp: App {
    // AppStore 承担原计划中 ModelContainer 的职责（JSON 文档持久化）
    @State private var store: AppStore = AppStore.load()
    @Environment(\.scenePhase) private var scenePhase

    // 外观设置全局注入（强调色经 .tint，深色模式经 .preferredColorScheme）
    @AppStorage(AppearanceSettings.accentKey) private var accentIndex = 0
    @AppStorage(AppearanceSettings.schemeKey) private var schemeIndex = 0

    var body: some Scene {
        WindowGroup {
            NovelListView()
                .environment(store)
                .tint(AppTheme.accentPresets[accentIndex % AppTheme.accentPresets.count])
                .preferredColorScheme(colorSchemeOverride)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { store.save() }
        }
    }

    private var colorSchemeOverride: ColorScheme? {
        switch schemeIndex {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

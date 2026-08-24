import SwiftUI

@main
struct ZhiMingApp: App {
    // AppStore 承担原计划中 ModelContainer 的职责（JSON 文档持久化）
    @StateObject private var store: AppStore = AppStore.load()
    @Environment(\.scenePhase) private var scenePhase

    // 外观设置全局注入（强调色经 .tint，深色模式经 .preferredColorScheme）
    @AppStorage(AppearanceSettings.accentKey) private var accentIndex = 0
    @AppStorage(AppearanceSettings.schemeKey) private var schemeIndex = 0

    init() {
        // iOS 15：TextEditor 无 scrollContentBackground，用 UITextView 外观统一透明背景（深色模式正确）
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            NovelListView()
                .environmentObject(store)
                .tint(AppearanceSettings.accentColor(for: accentIndex))
                .preferredColorScheme(colorSchemeOverride)
        }
        .onChange(of: scenePhase) { newPhase in
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

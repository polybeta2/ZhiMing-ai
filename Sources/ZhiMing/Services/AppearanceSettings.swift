import SwiftUI
import UIKit

/// 外观设置：写入 UserDefaults（绝不存放 API Key），经根视图 .tint / .preferredColorScheme 全局生效
enum AppearanceSettings {
    static let accentKey = "zhiming.accentIndex"
    static let schemeKey = "zhiming.colorScheme"   // 0 跟随系统 / 1 浅色 / 2 深色

    static var accentIndex: Int {
        get { UserDefaults.standard.object(forKey: accentKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: accentKey) }
    }

    static var accentColor: Color { accentColor(for: accentIndex) }

    static func accentColor(for index: Int) -> Color {
        AppTheme.accentPresets[max(0, index) % AppTheme.accentPresets.count]
    }

    static var schemeIndex: Int {
        get { UserDefaults.standard.object(forKey: schemeKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: schemeKey) }
    }

    static var preferredColorScheme: ColorScheme? {
        switch schemeIndex {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    static var schemeLabel: String {
        switch schemeIndex {
        case 1: return "浅色"
        case 2: return "深色"
        default: return "跟随系统"
        }
    }
}

/// 生成中保持屏幕常亮（Kelivo 同款细节）
enum KeepAwake {
    @MainActor
    static func set(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
    }
}

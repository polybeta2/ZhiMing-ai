import SwiftUI

/// 设计令牌：数值取自 Kelivo `design_tokens.dart` 与 `chat_bubble_style.dart`
enum AppTheme {
    static let radiusCapsule: CGFloat = 28      // 输入栏/按钮
    static let radiusBubble: CGFloat = 16       // 消息气泡
    static let radiusCard: CGFloat = 20         // 卡片
    static let spacing: [CGFloat] = [4, 8, 12, 16, 20]
    static let bubbleMaterialOpacity = 0.66
    static let accentPresets: [Color] = [
        Color(red: 0.30, green: 0.36, blue: 0.57),   // 蓝紫（Kelivo default）
        .blue, .green, .purple, .orange
    ]
}

// MARK: - hex ↔ Color 转换（Novel.accentColorHex 与强调色设置用）

extension Color {
    /// 形如 "#4D5C91" 或 "4D5C91" 的 hex 字符串
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    /// 输出形如 "#4D5C91"
    var hexString: String {
        #if canImport(UIKit)
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        func byte(_ i: Int) -> Int {
            let idx = min(i, components.count - 1)
            return Int((components[idx] * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", byte(0), byte(1), byte(2))
        #else
        return "#000000"
        #endif
    }
}

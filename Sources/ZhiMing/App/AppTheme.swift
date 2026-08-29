#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 设计令牌：数值取自 Kelivo `design_tokens.dart` 与 `chat_bubble_style.dart`，
/// 叠加 Apple HIG 化的语义层（弹簧动画 / 按压反馈 / 卡片语义 / 触感），全部 iOS 15 可用。
enum AppTheme {
    static let radiusCapsule: CGFloat = 28      // 输入栏/按钮
    static let radiusBubble: CGFloat = 18       // 消息气泡（iMessage 为 18）
    static let radiusTail: CGFloat = 4          // 气泡尾角小圆角
    static let radiusCard: CGFloat = 16         // 卡片（iOS 分组卡标准）
    static let spacing: [CGFloat] = [4, 8, 12, 16, 20]
    static let bubbleMaterialOpacity = 0.66
    static let accentPresets: [Color] = [
        Color(red: 0.30, green: 0.36, blue: 0.57),   // 蓝紫（Kelivo default）
        .blue, .green, .purple, .orange
    ]

    /// Apple 语义弹簧（对应 Designing Fluid Interfaces：默认近临界阻尼，响应 0.3–0.4s）
    enum Spring {
        /// 常规 UI 出现/消失/位移：无超调、干脆落定
        static let standard = Animation.spring(response: 0.35, dampingFraction: 0.86)
        /// 有动量的交互（轻扫/抛出后的收尾）：轻微回弹
        static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.76)
        /// 按压交互的瞬时响应
        static let press = Animation.spring(response: 0.22, dampingFraction: 1.0)
    }

    /// 卡片阴影（随浅色/深色自适应）
    static func cardShadow(for scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.45 : 0.08)
    }
}

// MARK: - 按压反馈（Apple 默认交互：触下即反馈，不等待抬起）
// 视觉等价于 SwiftUI iOS 17 的 .buttonStyle(.bordered) 按压；全程 iOS 15 可用的手写版。

struct ZMPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var opacity: Double = 1.0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? min(opacity, 0.85) : 1)
            .animation(AppTheme.Spring.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ZMPressableButtonStyle {
    /// 触下即时缩放反馈：`.buttonStyle(.zmPress)`
    static var zmPress: ZMPressableButtonStyle { ZMPressableButtonStyle() }
}

// MARK: - Apple 设置页惯例：彩色圆角方块图标容器（29pt 圆角 8，同 iOS 设置列表）
struct ZMSettingsIcon: View {
    let systemName: String
    var tint: Color = .accentColor

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(
                colors: [tint, tint.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 29, height: 29)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
    }
}

// MARK: - Apple 语义卡片（secondarySystemGroupedBackground + 细描边 + 软阴影）

private struct ZMCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = AppTheme.radiusCard
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        let padded = VStack(alignment: .leading) { content }
            .padding(padding ?? 0)
        return padded
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: AppTheme.cardShadow(for: scheme), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color(uiColor: .separator).opacity(scheme == .dark ? 0.4 : 0.16), lineWidth: 0.5)
            )
    }
}

extension View {
    /// 一张「浮在分组背景上的」Apple 风卡片。
    func zmCard(cornerRadius: CGFloat = AppTheme.radiusCard, padding: CGFloat? = nil) -> some View {
        modifier(ZMCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - iMessage 式气泡形状（尾侧下角为小圆角，iOS 15 自绘）

struct BubbleShape: Shape {
    let isUser: Bool
    var radius: CGFloat = AppTheme.radiusBubble
    var tailRadius: CGFloat = AppTheme.radiusTail

    func path(in rect: CGRect) -> Path {
        let tl = isUser ? radius : radius, tr = radius
        let bl = isUser ? radius : tailRadius
        let br = isUser ? tailRadius : radius
        return Path { p in
            p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr,
                     startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
            p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
    }
}

// MARK: - 触感反馈（Key Moments Only：成功/警告/轻按确认）

enum ZMHaptics {
    #if canImport(UIKit)
    @MainActor static var impactLight: UIImpactFeedbackGenerator {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }
    #endif

    static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
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
#endif

import UIKit
import SwiftUI

/// 发送前体量护栏（v1.7）：请求总字符超过 PromptLimits.requestWarnChars 时弹确认框。
/// 刻意使用 UIKit UIAlertController 而非 SwiftUI .alert——本项目已验证部分系统版本上
/// SwiftUI .alert 的按钮 action 不可靠（v1.5.2 教训）；此处按钮只 resume 异步延续，
/// 不承载任何 @State 业务写入，且经 DispatchQueue.main.async 派发，规避同类时序问题。
@MainActor
enum PromptGuard {

    /// 返回 true = 继续发送；false = 用户取消。低于阈值直接放行、零开销。
    static func authorized(totalChars: Int) async -> Bool {
        guard totalChars > PromptLimits.requestWarnChars else { return true }
        return await withCheckedContinuation { continuation in
            guard let root = Self.topMostViewController() else {
                // 找不到可用窗口（理论不发生）：放行，不阻塞创作流
                continuation.resume(returning: true)
                return
            }
            let alert = UIAlertController(
                title: "本次提示词较大",
                message: "请求合计约 \(totalChars) 字，超过 \(PromptLimits.requestWarnChars) 字告警线。\n可能触发上游上下文上限、显著拖慢首字响应或增加费用。仍要发送吗？",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "仍然发送", style: .default) { _ in
                DispatchQueue.main.async { continuation.resume(returning: true) }
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                DispatchQueue.main.async { continuation.resume(returning: false) }
            })
            root.present(alert, animated: true)
        }
    }

    /// keyWindow → presented 链最顶层的可呈现控制器
    private static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

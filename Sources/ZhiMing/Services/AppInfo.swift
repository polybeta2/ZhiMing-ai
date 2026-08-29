import Foundation

/// App 元信息：版本号等，统一从 Info.plist 读取，避免硬编码在多处漂移
enum AppInfo {
    /// CFBundleShortVersionString（如 2.2.0）；读取失败时回退占位符
    static var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }
}
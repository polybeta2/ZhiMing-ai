#if os(iOS) || os(macOS)
import Foundation

/// 原作 txt 收纳目录。该目录位于 App 的 Documents 下，Info.plist 已启用
/// UIFileSharingEnabled —— 通过「文件 App → 浏览 → 我的 iPhone → 织命 → origins」即可放入
/// 文件；LiveContainer 用户则在其文件面板进入本 App 的沙盒目录。
enum SourceOriginFolder {
    /// Documents/origins（不存在则创建；失败回退临时目录并保持读使用方容错）
    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("origins", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 是否可直接访问（目录存在）
    static var isAvailable: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// 列出目录内的候选文本文件（txt / utf8 / 无扩展名也列出，读取时再做编码识别）
    static func listTextFiles() -> [URL] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return [] }
        let textExts: Set<String> = ["txt", "utf8", "text", "plain"]
        return urls
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ext.isEmpty || textExts.contains(ext)
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
#endif
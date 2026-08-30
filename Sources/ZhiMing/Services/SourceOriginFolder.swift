#if os(iOS) || os(macOS)
import Foundation

/// 原作 txt 收纳目录（LiveContainer 不可用系统文件保存路径，故引导用户把原始 txt 放入本 App 的
/// Documents/origins 文件夹，再在「原作档案库 → 从 origins 导入」中选取分析）。
/// 该目录位于 App 的 Documents 下，可通过「文件 App → 我的 iPhone → 织命 → origins」或
/// LiveContainer 的文件面板直接放文件。
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
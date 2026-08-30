import Foundation

/// 续写原文边车：主库 JSON 是全量原子写，多 MB 原文不入库，
/// 存 Application Support/ZhiMing/continuations/<profileID>.txt，滚动注入时按需懒加载。
public enum ContinuationStore {

    /// 测试注入目录（nil = 默认 Application Support/ZhiMing/continuations）
    public static var overrideDirectory: URL?

    static var directoryURL: URL {
        if let overrideDirectory {
            try? FileManager.default.createDirectory(at: overrideDirectory, withIntermediateDirectories: true)
            return overrideDirectory
        }
        let fm = FileManager.default
        // 启用 UIFileSharingEnabled 后 Documents 会暴露给文件 App，多 MB 原文边车
        // 迁往 Application Support（与 source_scan.sqlite 同级），Documents 只留 origins
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = support.appendingPathComponent("ZhiMing/continuations", isDirectory: true)
        // 一次性迁移：旧版（≤v2.12.2）曾放 Documents/continuations
        let legacy = (fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
            .appendingPathComponent("continuations", isDirectory: true)
        if fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.moveItem(at: legacy, to: dir)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(profileID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(profileID.uuidString).txt")
    }

    /// 写入 1~X 章原文；成功返回 true
    @discardableResult
    public static func save(text: String, profileID: UUID) -> Bool {
        do {
            try text.write(to: fileURL(profileID: profileID), atomically: true, encoding: .utf8)
            return true
        } catch { return false }
    }

    /// 全量读取（换章重析/预览用）；不存在返回 nil
    public static func load(profileID: UUID) -> String? {
        try? String(contentsOf: fileURL(profileID: profileID), encoding: .utf8)
    }

    /// 末尾原文（滚动注入文风锚点）：取尾部 maxChars 字符，并对齐到最近的章节标记行起点
    public static func loadTail(profileID: UUID, maxChars: Int) -> String? {
        guard let text = load(profileID: profileID) else { return nil }
        guard text.count > maxChars else { return text }
        let tail = String(text.suffix(maxChars))
        let lines = tail.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() where looksLikeChapterMarker(line) {
            return "……（前文略）\n" + lines[i...].joined(separator: "\n")
        }
        return "……（前文略）\n" + tail
    }

    /// 章节标记行启发式（与切章同源的宽松版；不限制行长，
    /// 兼容「marker+正文粘连」的整行章节与正文句子紧贴标记的场景，误对齐代价低）
    private static func looksLikeChapterMarker(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.hasPrefix("第") || trimmed.hasPrefix("Chapter")
            || trimmed.hasPrefix("序章") || trimmed.hasPrefix("楔子") || trimmed.hasPrefix("尾声")
    }

    /// 删除边车（档案删除时清理）
    public static func delete(profileID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(profileID: profileID))
    }
}
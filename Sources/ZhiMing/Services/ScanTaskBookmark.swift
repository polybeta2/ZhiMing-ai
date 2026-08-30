#if os(iOS) || os(macOS)
import Foundation
import ZhiMingCore

/// 扫描任务书签：进程被杀/退出 App 后，从断点继续分析的能力。
/// 元数据入 Documents/scan_tasks/<pid>.json，源文本入同目录 <pid>.txt
/// （源文本不从内存恢复——VM 是临时实例，退出即丢，必须落盘）。
/// SQLite（SourceScanCache）已按块存 done 状态与阶段摘要，此处只需恢复
/// 「pid + 源文本 + 任务参数」，VM.start 即可自动跳过已完成块续跑。
struct ScanTaskBookmark: Codable, Identifiable {
    var id: UUID { pid }
    let pid: UUID
    var title: String
    var modeRaw: String          // ScanMode rawValue
    var batchSize: Int
    var isContinuation: Bool
    var totalChunks: Int
    // Provider 快照（Keychain 里 key 挂在 apiKeyID 名下，必须原样还原才能取到）
    var providerName: String
    var providerBaseUrl: String
    var providerModel: String
    var providerKeyID: String
    var startedAt: Date

    private static var dirURL: URL {
        // 与 continuations 同理：Documents 启用文件共享后只留 origins，任务书签放 Application Support
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing/scan_tasks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func metaURL(_ pid: UUID) -> URL { dirURL.appendingPathComponent("\(pid.uuidString).json") }
    private static func textURL(_ pid: UUID) -> URL { dirURL.appendingPathComponent("\(pid.uuidString).txt") }

    /// 保存任务书签 + 源文本（可覆盖：每次 start 刷新 totalChunks/参数）
    @discardableResult
    static func save(text: String, profileID: UUID, title: String, mode: ScanMode,
                     batchSize: Int, isContinuation: Bool, totalChunks: Int,
                     provider: ProviderConfig) -> Bool {
        let bm = ScanTaskBookmark(
            pid: profileID, title: title, modeRaw: mode.rawValue, batchSize: batchSize,
            isContinuation: isContinuation, totalChunks: totalChunks,
            providerName: provider.name, providerBaseUrl: provider.baseUrl,
            providerModel: provider.modelName, providerKeyID: provider.apiKeyID,
            startedAt: .now)
        do {
            let data = try JSONEncoder().encode(bm)
            try data.write(to: metaURL(profileID), options: .atomic)
            try text.write(to: textURL(profileID), atomically: true, encoding: .utf8)
            return true
        } catch { return false }
    }

    /// 全部未完成任务（按开始时间倒序）
    static func all() -> [ScanTaskBookmark] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        else { return [] }
        let metas = files.filter { $0.pathExtension == "json" }
        let decoded = metas.compactMap { url -> ScanTaskBookmark? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ScanTaskBookmark.self, from: data)
        }
        return decoded.sorted { $0.startedAt > $1.startedAt }
    }

    /// 读取某任务的源文本（恢复分析需要重新切块）
    static func loadText(profileID: UUID) -> String? {
        try? String(contentsOf: textURL(profileID), encoding: .utf8)
    }

    /// 删除书签 + 源文本（分析完成/用户放弃时调用）
    static func delete(profileID: UUID) {
        try? FileManager.default.removeItem(at: metaURL(profileID))
        try? FileManager.default.removeItem(at: textURL(profileID))
    }
}
#endif
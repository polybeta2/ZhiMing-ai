#if os(iOS) || os(macOS)
import Foundation
import SQLite3
import ZhiMingCore

/// Swift 模块未导出 SQLITE_TRANSIENT 宏：显式桥接为「绑定后由 SQLite 复制一份」的析构回调
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 蒸馏会话缓存（SQLite，单行 KV）：S2 机制分析是最贵的一次调用，完成后立即落盘；
/// 之后失败/中断/杀进程，重新打开蒸馏向导可从 S3 继续，不必重跑机制分析。
/// 缓存是「可丢弃数据」：任何读写出错都静默，绝不阻断主流程（与 CreationSessionCache 同纪律）。
enum StyleDistillCache {
    /// 单行缓存键（蒸馏向导同时至多一个会话）
    private static let slot = "latest"

    struct Payload: Codable {
        var sourceText: String
        var sourceNote: String
        var analysisRaw: String
        var savedAt: Date
    }

    private static var dbURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("style_distill_cache.sqlite")
    }

    private static var db: OpaquePointer?
    private static var opened = false

    private static func openIfNeeded() -> OpaquePointer? {
        if opened { return db }
        opened = true
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(dbURL.path, &handle, flags, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return nil
        }
        db = handle
        let create = """
        CREATE TABLE IF NOT EXISTS style_distill_cache (
            slot TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        sqlite3_exec(handle, create, nil, nil, nil)
        return db
    }

    /// S2 完成即落盘（UPSERT）
    static func save(sourceText: String, sourceNote: String, analysisRaw: String) {
        let payload = Payload(sourceText: sourceText, sourceNote: sourceNote,
                              analysisRaw: analysisRaw, savedAt: .now)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8),
              let db = openIfNeeded() else { return }
        let sql = """
        INSERT INTO style_distill_cache (slot, payload, updated_at) VALUES (?, ?, ?)
        ON CONFLICT(slot) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (slot as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (json as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    /// 读取可恢复会话（无记录或损坏返回 nil）
    static func load() -> Payload? {
        guard let db = openIfNeeded() else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM style_distill_cache WHERE slot = ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (slot as NSString).utf8String, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0),
              let data = String(cString: cString).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// 蒸馏成功入库或用户主动放弃时清除
    static func remove() {
        guard let db = openIfNeeded() else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM style_distill_cache WHERE slot = ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (slot as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }
}
#endif

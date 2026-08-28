import Foundation
import SQLite3

/// Swift 模块未导出 SQLITE_TRANSIENT 宏：显式桥接为「绑定后由 SQLite 复制一份」的析构回调
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 立项会话缓存（SQLite）：把 CreationSessionViewModel 的流程状态（阶段/问答/提案/蓝图）
/// 落盘到本地 SQLite，退出书籍页/杀进程后重进可原样恢复，AI 上下文不丢失。
/// 缓存是「可丢弃数据」：任何读写出错都静默，绝不阻断主流程。
/// 存储结构：单表 KV，key = ChatThread.id，value = 状态快照 JSON。
enum CreationSessionCache {
    private static var dbURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("creation_sessions.sqlite")
    }

    /// 复用连接：懒加载单次打开，避免每次读写重建连接
    private static var db: OpaquePointer?
    private static var opened = false

    /// 打开连接 + 建表（幂等）。失败则保持 nil，后续操作全部短路。
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
        CREATE TABLE IF NOT EXISTS creation_sessions (
            thread_id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        sqlite3_exec(handle, create, nil, nil, nil)
        return db
    }

    /// 写入（UPSERT）会话快照
    static func save(payload: String, forThread id: UUID) {
        guard let db = openIfNeeded() else { return }
        let sql = """
        INSERT INTO creation_sessions (thread_id, payload, updated_at) VALUES (?, ?, ?)
        ON CONFLICT(thread_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (payload as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    /// 读取会话快照（无记录返回 nil）
    static func load(forThread id: UUID) -> String? {
        guard let db = openIfNeeded() else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM creation_sessions WHERE thread_id = ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cString)
    }

    /// 删除会话快照（作品创建成功/会话终结时调用）
    static func remove(forThread id: UUID) {
        guard let db = openIfNeeded() else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM creation_sessions WHERE thread_id = ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    /// 清空全部缓存（开发者工具/调试用；正常流程用 remove 按线程删）
    static func clearAll() {
        guard let db = openIfNeeded() else { return }
        sqlite3_exec(db, "DELETE FROM creation_sessions;", nil, nil, nil)
    }
}
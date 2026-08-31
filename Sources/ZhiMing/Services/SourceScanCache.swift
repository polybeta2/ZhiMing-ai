#if os(iOS) || os(macOS)
import Foundation
import SQLite3
import ZhiMingCore

/// Swift 模块未导出 SQLITE_TRANSIENT 宏：显式桥接为「绑定后由 SQLite 复制一份」的析构回调
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 同人扫描明细缓存（SQLite，chunk 粒度断点续传）。
/// chunk_meta 存块状态（done 后微摘要 JSON 落 payload）；reduce_texts 存阶段摘要。
/// 缓存是「可丢弃数据」：任何读写出错都静默，绝不阻断主流程（与 CreationSessionCache 同惯例）。
enum SourceScanCache {

    private static var dbURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("source_scan.sqlite")
    }

    /// 复用连接：懒加载单次打开
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
        CREATE TABLE IF NOT EXISTS chunk_meta (
            profile TEXT NOT NULL, idx INTEGER NOT NULL, status TEXT NOT NULL,
            payload TEXT, tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0,
            updated_at REAL, PRIMARY KEY (profile, idx));
        CREATE TABLE IF NOT EXISTS reduce_texts (
            profile TEXT NOT NULL, seq INTEGER NOT NULL, text TEXT NOT NULL,
            PRIMARY KEY (profile, seq));
        CREATE TABLE IF NOT EXISTS scan_meta (
            profile TEXT NOT NULL, k TEXT NOT NULL, v INTEGER, PRIMARY KEY (profile, k));
        """
        sqlite3_exec(handle, create, nil, nil, nil)
        return db
    }

    /// 落块状态（UPSERT）；status 取值 pending|done|failed，done 时 payload 存微摘要 JSON
    static func mark(profile: UUID, idx: Int, status: String, payload: String? = nil,
                     tokensIn: Int = 0, tokensOut: Int = 0) {
        guard let db = openIfNeeded() else { return }
        let sql = """
        INSERT INTO chunk_meta (profile, idx, status, payload, tokens_in, tokens_out, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(profile, idx) DO UPDATE SET
            status = excluded.status, payload = excluded.payload,
            tokens_in = excluded.tokens_in, tokens_out = excluded.tokens_out,
            updated_at = excluded.updated_at;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(idx))
        sqlite3_bind_text(stmt, 3, (status as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let payload {
            sqlite3_bind_text(stmt, 4, (payload as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_int(stmt, 5, Int32(tokensIn))
        sqlite3_bind_int(stmt, 6, Int32(tokensOut))
        sqlite3_bind_double(stmt, 7, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    /// 已完成的块下标（断点续传：跳过这些块，只补 pending）
    static func doneIndexes(profile: UUID) -> Set<Int> {
        guard let db = openIfNeeded() else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT idx FROM chunk_meta WHERE profile = ? AND status = 'done';",
                                 -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        var result: Set<Int> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.insert(Int(sqlite3_column_int(stmt, 0)))
        }
        return result
    }

    /// 存一段归并产物（阶段摘要，按 seq 有序）
    static func saveReduce(profile: UUID, seq: Int, text: String) {
        guard let db = openIfNeeded() else { return }
        let sql = """
        INSERT INTO reduce_texts (profile, seq, text) VALUES (?, ?, ?)
        ON CONFLICT(profile, seq) DO UPDATE SET text = excluded.text;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(seq))
        sqlite3_bind_text(stmt, 3, (text as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    /// 读全部阶段摘要（按 seq 升序，终归并输入）
    static func loadReduceStrings(profile: UUID) -> [String] {
        guard let db = openIfNeeded() else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT text FROM reduce_texts WHERE profile = ? ORDER BY seq;",
                                 -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        var result: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0) {
            result.append(String(cString: cString))
        }
        return result
    }

    /// 读回全部已完成块的微摘要（滚动归并恢复：断点后已 done 未归并的块从这里续上）
    static func loadMicros(profile: UUID) -> [(pos: Int, micro: SourceMicroSummarizer.MicroSummary)] {
        guard let db = openIfNeeded() else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT idx, payload FROM chunk_meta WHERE profile = ? AND status = 'done' AND payload IS NOT NULL ORDER BY idx;",
                                 -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        var result: [(Int, SourceMicroSummarizer.MicroSummary)] = []
        while sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 1),
              let data = String(cString: cString).data(using: .utf8),
              let micro = try? JSONDecoder().decode(SourceMicroSummarizer.MicroSummary.self, from: data) {
            result.append((Int(sqlite3_column_int(stmt, 0)), micro))
        }
        return result
    }

    /// 已归并到的块进度（滚动归并：仅 pos 大于该值的 done 块需要归并）
    static func reducedUpto(profile: UUID) -> Int {
        guard let db = openIfNeeded() else { return -1 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT v FROM scan_meta WHERE profile = ? AND k = 'reduced_upto';",
                                 -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return -1
    }

    /// 更新归并进度（单调递增；归并完成一批后调用）
    static func setReducedUpto(profile: UUID, pos: Int) {
        guard let db = openIfNeeded() else { return }
        let sql = """
        INSERT INTO scan_meta (profile, k, v) VALUES (?, 'reduced_upto', ?)
        ON CONFLICT(profile, k) DO UPDATE SET v = excluded.v;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(pos))
        sqlite3_step(stmt)
    }

    /// 清空某档案的全部扫描明细（换档重扫/删除档案时调用）
    static func clear(profile: UUID) {
        guard let db = openIfNeeded() else { return }
        let deletes = [
            "DELETE FROM chunk_meta WHERE profile = ?;",
            "DELETE FROM reduce_texts WHERE profile = ?;",
            "DELETE FROM scan_meta WHERE profile = ?;",
        ]
        for d in deletes {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, d, -1, &stmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_text(stmt, 1, (profile.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
#endif
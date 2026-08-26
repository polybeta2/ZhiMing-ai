import Foundation
import Combine

/// 全局数据仓库：承担原计划中 SwiftData ModelContainer/ModelContext 的职责。
/// JSON 文档原子写入 Application Support，字段与关系语义不变。
/// iOS 15 兼容：ObservableObject + 手动 objectWillChange 通知。
@MainActor
final class AppStore: ObservableObject {
    @Published var novels: [Novel] = []
    @Published var providers: [ProviderConfig] = []
    /// 每次保存自增，驱动观察 store 的视图刷新（嵌套模型变更的兜底通知）
    @Published private(set) var revision = 0
    /// 最近一次保存失败的提示（nil = 正常）；由根界面以 alert 呈现，不再静默丢数据
    @Published private(set) var lastSaveError: String?

    private struct Document: Codable {
        var novels: [Novel]
        var providers: [ProviderConfig]
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 数据文件：Application Support/ZhiMing/library.json
    static var fileURL: URL { directory.appendingPathComponent("library.json") }
    /// 单代备份：主文件损坏/不可读时的最后恢复手段
    static var backupURL: URL { directory.appendingPathComponent("library.json.bak") }

    static func load() -> AppStore {
        let store = AppStore()
        let fm = FileManager.default
        let primaryExisted = fm.fileExists(atPath: fileURL.path)
        let backupExisted = fm.fileExists(atPath: backupURL.path)

        if let doc = decodeDocument(at: fileURL) ?? decodeDocument(at: backupURL) {
            store.novels = doc.novels
            store.providers = doc.providers
            return store
        }

        // 主文件与备份均不可读：把损坏文件改名搁置（绝不原地覆盖），再从空库开始。
        // DEBUG 演示数据仅在全新安装（从未有数据文件）时注入，避免掩盖真实的数据丢失。
        if primaryExisted || backupExisted {
            quarantineUnreadableFiles()
        }
        #if DEBUG
        if !primaryExisted && !backupExisted {
            SeedData.inject(into: store)
        }
        #endif
        return store
    }

    private static func decodeDocument(at url: URL) -> Document? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Document.self, from: data)
    }

    private static func quarantineUnreadableFiles() {
        let stamp = Int(Date().timeIntervalSince1970)
        for url in [fileURL, backupURL] where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.moveItem(
                at: url,
                to: URL(fileURLWithPath: url.path + ".corrupt-\(stamp)")
            )
        }
    }

    /// 备份节流水位：≥60s 才刷新一次备份，避免逐键防抖保存带来双倍磁盘写入
    private static var lastBackupAt = Date.distantPast

    /// 原子保存；所有写操作完成后调用。失败不再静默：写入 lastSaveError 供界面提示。
    func save() {
        revision += 1
        let doc = Document(novels: novels, providers: providers)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(doc) else {
            lastSaveError = "数据编码失败，本次更改尚未写入磁盘"
            return
        }
        do {
            try data.write(to: Self.fileURL, options: [.atomic])
            lastSaveError = nil
            Self.refreshBackupThrottled(with: data)
        } catch {
            // 内容仍在内存对象图中，用户可排查磁盘后再次触发保存
            lastSaveError = "保存失败：\(error.localizedDescription)。请检查存储空间后继续编辑，稍后会自动重试。"
        }
    }

    private static func refreshBackupThrottled(with data: Data) {
        guard Date().timeIntervalSince(lastBackupAt) >= 60 else { return }
        lastBackupAt = Date()
        try? data.write(to: backupURL, options: [.atomic])
    }

    func clearSaveError() { lastSaveError = nil }

    var defaultProvider: ProviderConfig? {
        providers.first(where: \.isDefault) ?? providers.first
    }

    // MARK: - 便捷操作

    func deleteNovel(_ novel: Novel) {
        // 子树（卷/章/角色/世界观/会话）随对象图一并释放，等价级联删除
        novels.removeAll { $0.id == novel.id }
        save()
    }

    func deleteProvider(_ provider: ProviderConfig) {
        // 先落盘再删密钥：若保存失败重启后提供商仍可见，用户可重新补录密钥而非凭空消失
        providers.removeAll { $0.id == provider.id }
        if providers.isEmpty == false, !providers.contains(where: \.isDefault) {
            providers.first?.isDefault = true
        }
        save()
        _ = KeychainHelper.delete(account: provider.apiKeyID)
    }

    func makeDefault(_ provider: ProviderConfig) {
        for p in providers { p.isDefault = (p.id == provider.id) }
        save()
    }
}

#if DEBUG
extension AppStore {
    /// 预览专用：不落盘
    static func preview() -> AppStore {
        let store = AppStore()
        SeedData.inject(into: store)
        return store
    }
}
#endif

import Foundation
#if canImport(Combine)
import Combine
#endif

/// 全局数据仓库：承担原计划中 SwiftData ModelContainer/ModelContext 的职责。
/// JSON 文档原子写入 Application Support，字段与关系语义不变。
/// iOS 15 兼容：ObservableObject + 手动 objectWillChange 通知。
@MainActor
public final class AppStore: ObservableObject {
    @Published public var novels: [Novel] = []
    @Published public var providers: [ProviderConfig] = []
    /// 文风档案库（全局，跨书复用）
    @Published public var styleProfiles: [StyleProfile] = []
    /// 原作档案库（一本原作一个档案，多本同人共享，分析一次永久复用）
    @Published public var sourceProfiles: [SourceNovelProfile] = []
    /// 每次保存自增，驱动观察 store 的视图刷新（嵌套模型变更的兜底通知）
    @Published public private(set) var revision = 0
    /// 最近一次保存失败的提示（nil = 正常）；由根界面以 alert 呈现，不再静默丢数据
    @Published public private(set) var lastSaveError: String?
    /// 删除提供商时清理其 Keychain 密钥的钩子；App 启动注入，未注入（Linux 测试）为无操作
    public var providerKeyDeleter: ((String) -> Void)?

    private struct Document: Codable {
        var novels: [Novel]
        var providers: [ProviderConfig]
        var styleProfiles: [StyleProfile]?
        var sourceProfiles: [SourceNovelProfile]?
    }

    /// 测试注入：重定向数据目录（Linux XCTest 指向临时目录，避免读写真实用户数据）
    public static var directoryOverride: URL?

    private static var directory: URL {
        if let override = directoryOverride {
            try? FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 数据文件：Application Support/ZhiMing/library.json
    public static var fileURL: URL { directory.appendingPathComponent("library.json") }
    /// 单代备份：主文件损坏/不可读时的最后恢复手段
    public static var backupURL: URL { directory.appendingPathComponent("library.json.bak") }

    public static func load() -> AppStore {
        let store = AppStore()
        let fm = FileManager.default
        let primaryExisted = fm.fileExists(atPath: fileURL.path)
        let backupExisted = fm.fileExists(atPath: backupURL.path)

        if let doc = decodeDocument(at: fileURL) ?? decodeDocument(at: backupURL) {
            store.novels = doc.novels
            store.providers = doc.providers
            store.styleProfiles = doc.styleProfiles ?? []
            store.sourceProfiles = doc.sourceProfiles ?? []
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
    public func save() {
        revision += 1
        let doc = Document(novels: novels, providers: providers, styleProfiles: styleProfiles,
                           sourceProfiles: sourceProfiles)
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

    public func clearSaveError() { lastSaveError = nil }

    public var defaultProvider: ProviderConfig? {
        providers.first(where: \.isDefault) ?? providers.first
    }

    // MARK: - 便捷操作

    public func deleteNovel(_ novel: Novel) {
        // 子树（卷/章/角色/世界观/会话）随对象图一并释放，等价级联删除
        novels.removeAll { $0.id == novel.id }
        save()
    }

    public func deleteProvider(_ provider: ProviderConfig) {
        // 先落盘再删密钥：若保存失败重启后提供商仍可见，用户可重新补录密钥而非凭空消失
        providers.removeAll { $0.id == provider.id }
        if providers.isEmpty == false, !providers.contains(where: \.isDefault) {
            providers.first?.isDefault = true
        }
        save()
        // Keychain 依赖 Security 框架，不进 ZhiMingCore：由 App 层启动时注入清理钩子
        providerKeyDeleter?(provider.apiKeyID)
    }

    public func makeDefault(_ provider: ProviderConfig) {
        for p in providers { p.isDefault = (p.id == provider.id) }
        save()
    }

    // MARK: - 文风档案库

    public func upsertStyleProfile(_ profile: StyleProfile) {
        profile.updatedAt = .now
        if let index = styleProfiles.firstIndex(where: { $0.id == profile.id }) {
            styleProfiles[index] = profile
        } else {
            styleProfiles.append(profile)
        }
        save()
    }

    public func deleteStyleProfile(_ profile: StyleProfile) {
        styleProfiles.removeAll { $0.id == profile.id }
        // 解绑所有引用该书档案的作品，避免悬挂 UUID
        for novel in novels where novel.activeStyleProfileID == profile.id {
            novel.activeStyleProfileID = nil
        }
        save()
    }

    /// 档案被多少本书绑定（删除前提示用）
    public func bindingCount(of profile: StyleProfile) -> Int {
        novels.filter { $0.activeStyleProfileID == profile.id }.count
    }

    // MARK: - 原作档案库

    public func upsertSourceProfile(_ profile: SourceNovelProfile) {
        if let index = sourceProfiles.firstIndex(where: { $0.id == profile.id }) {
            sourceProfiles[index] = profile
        } else {
            sourceProfiles.append(profile)
        }
        save()
    }

    public func deleteSourceProfile(_ profile: SourceNovelProfile) {
        sourceProfiles.removeAll { $0.id == profile.id }
        // 解绑所有引用该档案的同人书，避免悬挂 UUID
        for novel in novels where novel.sourceProfileID == profile.id {
            novel.sourceProfileID = nil
        }
        save()
    }

    /// 档案被多少本书引用（删除前提示用）
    public func sourceBindingCount(of profile: SourceNovelProfile) -> Int {
        novels.filter { $0.sourceProfileID == profile.id }.count
    }
}

#if DEBUG
public extension AppStore {
    /// 预览专用：不落盘
    static func preview() -> AppStore {
        let store = AppStore()
        SeedData.inject(into: store)
        return store
    }
}
#endif

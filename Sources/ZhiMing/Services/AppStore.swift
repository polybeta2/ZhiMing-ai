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

    private struct Document: Codable {
        var novels: [Novel]
        var providers: [ProviderConfig]
    }

    /// 数据文件：Application Support/ZhiMing/library.json
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    static func load() -> AppStore {
        let store = AppStore()
        if let data = try? Data(contentsOf: fileURL),
           let doc = try? JSONDecoder().decode(Document.self, from: data) {
            store.novels = doc.novels
            store.providers = doc.providers
        } else {
            #if DEBUG
            SeedData.inject(into: store)
            #endif
        }
        return store
    }

    /// 原子保存；所有写操作完成后调用
    func save() {
        revision += 1
        let doc = Document(novels: novels, providers: providers)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(doc) else { return }
        try? data.write(to: Self.fileURL, options: [.atomic])
    }

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
        KeychainHelper.delete(account: provider.apiKeyID)
        providers.removeAll { $0.id == provider.id }
        if providers.isEmpty == false, !providers.contains(where: \.isDefault) {
            providers.first?.isDefault = true
        }
        save()
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

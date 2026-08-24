import Foundation
import Combine

// 说明：本工具链（Windows/WSL + xtool 交叉编译）无法使用 SwiftData 的闭源宏
// （xtool-org/xtool#149 已确认）。持久层改为「ObservableObject 模型 + JSON 文档存储」，
// 实体字段、关系与级联语义与实施计划第四节保持一致；删除作品即整体移除子树，天然级联。
// iOS 15 兼容：Observation(@Observable) 为 iOS 17+，此处统一用 Combine 的 ObservableObject。

final class Novel: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    @Published var synopsis: String                 // 一句话创意/梗概
    @Published var genre: String?
    @Published var perspective: String?             // 叙事视角（第一人称/第三人称…）
    @Published var styleGuide: String?              // 风格约束（续写时必注入）
    @Published var accentColorHex: String?
    @Published var createdAt: Date
    @Published var updatedAt: Date

    @Published var volumes: [Volume] = []
    @Published var characters: [CharacterCard] = []
    @Published var worldEntries: [WorldEntry] = []
    @Published var chatThreads: [ChatThread] = []

    init(id: UUID = UUID(), title: String, synopsis: String = "") {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Codable（反向引用不入档，解码后重建）

    enum CodingKeys: String, CodingKey {
        case id, title, synopsis, genre, perspective, styleGuide
        case accentColorHex, createdAt, updatedAt
        case volumes, characters, worldEntries, chatThreads
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        synopsis = try c.decode(String.self, forKey: .synopsis)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        perspective = try c.decodeIfPresent(String.self, forKey: .perspective)
        styleGuide = try c.decodeIfPresent(String.self, forKey: .styleGuide)
        accentColorHex = try c.decodeIfPresent(String.self, forKey: .accentColorHex)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        volumes = try c.decode([Volume].self, forKey: .volumes)
        characters = try c.decode([CharacterCard].self, forKey: .characters)
        worldEntries = try c.decode([WorldEntry].self, forKey: .worldEntries)
        chatThreads = try c.decode([ChatThread].self, forKey: .chatThreads)
        for v in volumes {
            v.novel = self
            for ch in v.chapters {
                ch.volume = v
                ch.snapshots.forEach { $0.chapter = ch }
                ch.summary?.chapter = ch
            }
        }
        characters.forEach { $0.novel = self }
        worldEntries.forEach { $0.novel = self }
        chatThreads.forEach { $0.novel = self }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(synopsis, forKey: .synopsis)
        try c.encodeIfPresent(genre, forKey: .genre)
        try c.encodeIfPresent(perspective, forKey: .perspective)
        try c.encodeIfPresent(styleGuide, forKey: .styleGuide)
        try c.encodeIfPresent(accentColorHex, forKey: .accentColorHex)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(volumes, forKey: .volumes)
        try c.encode(characters, forKey: .characters)
        try c.encode(worldEntries, forKey: .worldEntries)
        try c.encode(chatThreads, forKey: .chatThreads)
    }
}

final class Volume: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var outline: String?                 // 卷纲
    @Published var sortOrder: Int
    weak var novel: Novel?

    @Published var chapters: [Chapter] = []

    init(id: UUID = UUID(), name: String, sortOrder: Int, outline: String? = nil) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.outline = outline
    }

    enum CodingKeys: String, CodingKey { case id, name, outline, sortOrder, chapters }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        outline = try c.decodeIfPresent(String.self, forKey: .outline)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        chapters = try c.decode([Chapter].self, forKey: .chapters)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(outline, forKey: .outline)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(chapters, forKey: .chapters)
    }
}

final class Chapter: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    @Published var detailedOutline: String?         // 本章细纲
    @Published var content: String                  // 正文
    @Published var sortOrder: Int
    @Published var wordCount: Int
    @Published var updatedAt: Date
    weak var volume: Volume?

    @Published var snapshots: [ChapterSnapshot] = []
    @Published var summary: ChapterSummary?

    init(id: UUID = UUID(), title: String, sortOrder: Int) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.content = ""
        self.wordCount = 0
        self.updatedAt = .now
    }

    enum CodingKeys: String, CodingKey {
        case id, title, detailedOutline, content, sortOrder, wordCount, updatedAt
        case snapshots, summary
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        detailedOutline = try c.decodeIfPresent(String.self, forKey: .detailedOutline)
        content = try c.decode(String.self, forKey: .content)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        wordCount = try c.decode(Int.self, forKey: .wordCount)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        snapshots = try c.decode([ChapterSnapshot].self, forKey: .snapshots)
        summary = try c.decodeIfPresent(ChapterSummary.self, forKey: .summary)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(detailedOutline, forKey: .detailedOutline)
        try c.encode(content, forKey: .content)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(wordCount, forKey: .wordCount)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(snapshots, forKey: .snapshots)
        try c.encodeIfPresent(summary, forKey: .summary)
    }
}

final class ChapterSummary: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var summaryText: String              // 本章摘要
    @Published var keyFacts: [String]               // 关键事实（叙事账本简化版）
    weak var chapter: Chapter?

    init(id: UUID = UUID(), summaryText: String, keyFacts: [String] = []) {
        self.id = id
        self.summaryText = summaryText
        self.keyFacts = keyFacts
    }

    enum CodingKeys: String, CodingKey { case id, summaryText, keyFacts }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        summaryText = try c.decode(String.self, forKey: .summaryText)
        keyFacts = try c.decode([String].self, forKey: .keyFacts)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(summaryText, forKey: .summaryText)
        try c.encode(keyFacts, forKey: .keyFacts)
    }
}

final class ChapterSnapshot: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var versionNumber: Int
    @Published var content: String
    @Published var triggerType: String              // manual_save / ai_insert / restore
    @Published var createdAt: Date
    weak var chapter: Chapter?

    init(id: UUID = UUID(), versionNumber: Int, content: String, triggerType: String) {
        self.id = id
        self.versionNumber = versionNumber
        self.content = content
        self.triggerType = triggerType
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, versionNumber, content, triggerType, createdAt }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        versionNumber = try c.decode(Int.self, forKey: .versionNumber)
        content = try c.decode(String.self, forKey: .content)
        triggerType = try c.decode(String.self, forKey: .triggerType)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(versionNumber, forKey: .versionNumber)
        try c.encode(content, forKey: .content)
        try c.encode(triggerType, forKey: .triggerType)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

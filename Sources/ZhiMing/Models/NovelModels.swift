import Foundation
import Observation

// 说明：本工具链（Windows/WSL + xtool 交叉编译）无法使用 SwiftData 的闭源宏
// （xtool-org/xtool#149 已确认）。持久层改为「@Observable 模型 + JSON 文档存储」，
// 实体字段、关系与级联语义与实施计划第四节保持一致；删除作品即整体移除子树，天然级联。

@Observable
final class Novel: Identifiable, Codable {
    let id: UUID
    var title: String
    var synopsis: String                 // 一句话创意/梗概
    var genre: String?
    var perspective: String?             // 叙事视角（第一人称/第三人称…）
    var styleGuide: String?              // 风格约束（续写时必注入）
    var accentColorHex: String?
    var createdAt: Date
    var updatedAt: Date

    var volumes: [Volume] = []
    var characters: [CharacterCard] = []
    var worldEntries: [WorldEntry] = []
    var chatThreads: [ChatThread] = []

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

    init(from decoder: Decoder) throws {
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

@Observable
final class Volume: Identifiable, Codable {
    let id: UUID
    var name: String
    var outline: String?                 // 卷纲
    var sortOrder: Int
    @ObservationIgnored weak var novel: Novel?

    var chapters: [Chapter] = []

    init(id: UUID = UUID(), name: String, sortOrder: Int, outline: String? = nil) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.outline = outline
    }

    enum CodingKeys: String, CodingKey { case id, name, outline, sortOrder, chapters }

    init(from decoder: Decoder) throws {
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

@Observable
final class Chapter: Identifiable, Codable {
    let id: UUID
    var title: String
    var detailedOutline: String?         // 本章细纲
    var content: String                  // 正文
    var sortOrder: Int
    var wordCount: Int
    var updatedAt: Date
    @ObservationIgnored weak var volume: Volume?

    var snapshots: [ChapterSnapshot] = []
    var summary: ChapterSummary?

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

    init(from decoder: Decoder) throws {
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

@Observable
final class ChapterSummary: Identifiable, Codable {
    let id: UUID
    var summaryText: String              // 本章摘要
    var keyFacts: [String]               // 关键事实（叙事账本简化版）
    @ObservationIgnored weak var chapter: Chapter?

    init(id: UUID = UUID(), summaryText: String, keyFacts: [String] = []) {
        self.id = id
        self.summaryText = summaryText
        self.keyFacts = keyFacts
    }

    enum CodingKeys: String, CodingKey { case id, summaryText, keyFacts }

    init(from decoder: Decoder) throws {
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

@Observable
final class ChapterSnapshot: Identifiable, Codable {
    let id: UUID
    var versionNumber: Int
    var content: String
    var triggerType: String              // manual_save / ai_insert / restore
    var createdAt: Date
    @ObservationIgnored weak var chapter: Chapter?

    init(id: UUID = UUID(), versionNumber: Int, content: String, triggerType: String) {
        self.id = id
        self.versionNumber = versionNumber
        self.content = content
        self.triggerType = triggerType
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, versionNumber, content, triggerType, createdAt }

    init(from decoder: Decoder) throws {
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

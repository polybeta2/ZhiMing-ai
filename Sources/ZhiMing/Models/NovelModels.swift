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
    /// 一句话立项时用户启用的示例标签 id（生成蓝图时按关键词命中注入预设内容）
    @Published var enabledTagIDs: [String] = []
    /// R18 增强：开启后写作/立项请求自动注入虚构情色写作规范（按输入语言二选一）
    @Published var r18Enabled: Bool = false
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
        case accentColorHex, enabledTagIDs, r18Enabled, createdAt, updatedAt
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
        enabledTagIDs = try c.decodeIfPresent([String].self, forKey: .enabledTagIDs) ?? []
        r18Enabled = try c.decodeIfPresent(Bool.self, forKey: .r18Enabled) ?? false
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
        try c.encode(enabledTagIDs, forKey: .enabledTagIDs)
        try c.encode(r18Enabled, forKey: .r18Enabled)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(volumes, forKey: .volumes)
        try c.encode(characters, forKey: .characters)
        try c.encode(worldEntries, forKey: .worldEntries)
        try c.encode(chatThreads, forKey: .chatThreads)
    }
}

extension Novel {
    /// R18 作品的强制强调色（血红色），开启期间不可修改
    static let r18AccentHex = "#CC0000"
    /// R18 免责说明三段文案（内联确认卡共用）
    static let r18NoticeText = "说明：此功能仅为合规的 R18 写作提示词注入，用于增强小说文采与场景表现力，并非「破甲」或「越狱」提示词。\n提醒：如需更高级别的 R18 内容生成，请自行配置相应模型或 API 权限，本功能不涉及任何绕过模型安全策略的操作。\n免责声明：生成的所有内容均由您自行负责，与本应用开发者及运营方无关。"
}

// MARK: - 卷章纲四维结构（情绪走向 / 冲突阶梯 / 信息差 / 场景卡）
// 方法论参考 awesome-novel-agent 的维度划分，结构为本项目自行设计。

/// 场景卡：本章一个场景的三要素
struct SceneCard: Codable, Equatable {
    var goal: String        // 主角这场想达成什么
    var obstacle: String    // 什么拦着
    var hook: String        // 什么悬念勾读者往下看

    init(goal: String = "", obstacle: String = "", hook: String = "") {
        self.goal = goal
        self.obstacle = obstacle
        self.hook = hook
    }

    var isEmpty: Bool {
        goal.trimmingCharacters(in: .whitespaces).isEmpty
            && obstacle.trimmingCharacters(in: .whitespaces).isEmpty
            && hook.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// 冲突阶梯的一级（核心冲突逐级升高）
struct ConflictRung: Codable, Equatable {
    var level: Int              // 层级序号（1 起）
    var obstacle: String        // 这一级的阻力/对手
    var turningPoint: String?   // 跨入该层的转折点

    init(level: Int, obstacle: String, turningPoint: String? = nil) {
        self.level = level
        self.obstacle = obstacle
        self.turningPoint = turningPoint
    }
}

/// 信息差：本卷「谁知道什么」从起点到终点的变化
struct InfoGap: Codable, Equatable {
    var start: String           // 卷初读者/主角知道什么
    var end: String             // 卷末将揭示或颠覆什么

    var isEmpty: Bool {
        start.trimmingCharacters(in: .whitespaces).isEmpty
            && end.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(start: String = "", end: String = "") {
        self.start = start
        self.end = end
    }
}

final class Volume: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var outline: String?                 // 卷纲
    /// 四维：情绪走向（按节拍，如 压抑→提升→打脸）
    @Published var emotionArc: [String]?
    /// 四维：冲突阶梯（核心冲突逐级升高）
    @Published var conflictLadder: [ConflictRung]?
    /// 四维：信息差（卷初谁知道什么 → 卷末揭示什么）
    @Published var infoGap: InfoGap?
    @Published var sortOrder: Int
    weak var novel: Novel?

    @Published var chapters: [Chapter] = []

    init(id: UUID = UUID(), name: String, sortOrder: Int, outline: String? = nil) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.outline = outline
    }

    enum CodingKeys: String, CodingKey {
        case id, name, outline, emotionArc, conflictLadder, infoGap
        case sortOrder, chapters
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        outline = try c.decodeIfPresent(String.self, forKey: .outline)
        emotionArc = try c.decodeIfPresent([String].self, forKey: .emotionArc)
        conflictLadder = try c.decodeIfPresent([ConflictRung].self, forKey: .conflictLadder)
        infoGap = try c.decodeIfPresent(InfoGap.self, forKey: .infoGap)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        chapters = try c.decode([Chapter].self, forKey: .chapters)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(outline, forKey: .outline)
        try c.encodeIfPresent(emotionArc, forKey: .emotionArc)
        try c.encodeIfPresent(conflictLadder, forKey: .conflictLadder)
        try c.encodeIfPresent(infoGap, forKey: .infoGap)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(chapters, forKey: .chapters)
    }
}

final class Chapter: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    @Published var detailedOutline: String?         // 本章细纲
    /// 场景卡：本章 1-3 个场景的三要素（目标/阻力/钩子）
    @Published var sceneCards: [SceneCard]?
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
        case id, title, detailedOutline, sceneCards, content, sortOrder, wordCount, updatedAt
        case snapshots, summary
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        detailedOutline = try c.decodeIfPresent(String.self, forKey: .detailedOutline)
        sceneCards = try c.decodeIfPresent([SceneCard].self, forKey: .sceneCards)
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
        try c.encodeIfPresent(sceneCards, forKey: .sceneCards)
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

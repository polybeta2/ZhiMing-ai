import Foundation
#if canImport(Combine)
import Combine
#endif

// 说明：本工具链（Windows/WSL + xtool 交叉编译）无法使用 SwiftData 的闭源宏
// （xtool-org/xtool#149 已确认）。持久层改为「ObservableObject 模型 + JSON 文档存储」，
// 实体字段、关系与级联语义与实施计划第四节保持一致；删除作品即整体移除子树，天然级联。
// iOS 15 兼容：Observation(@Observable) 为 iOS 17+，此处统一用 Combine 的 ObservableObject。

public final class Novel: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var title: String
    @Published public var synopsis: String                 // 一句话创意/梗概
    @Published public var genre: String?
    @Published public var perspective: String?             // 叙事视角（第一人称/第三人称…）
    @Published public var styleGuide: String?              // 风格约束（续写时必注入）
    @Published public var accentColorHex: String?
    /// 一句话立项时用户启用的示例标签 id（生成蓝图时按关键词命中注入预设内容）
    @Published public var enabledTagIDs: [String] = []
    /// R18 增强：开启后写作/立项请求自动注入虚构情色写作规范（按输入语言二选一）
    @Published public var r18Enabled: Bool = false
    /// 文风蒸馏：本书绑定的文风档案（nil = 未启用）；注入时与 styleGuide 并存，styleGuide 优先
    @Published public var activeStyleProfileID: UUID?
    /// 同人立项：本书引用的原作档案（nil = 普通书）；写作时按时间窗注入原作人物/事件防 OOC
    @Published public var sourceProfileID: UUID?
    @Published public var createdAt: Date
    @Published public var updatedAt: Date

    @Published public var volumes: [Volume] = []
    @Published public var characters: [CharacterCard] = []
    @Published public var worldEntries: [WorldEntry] = []
    @Published public var chatThreads: [ChatThread] = []
    @Published public var foreshadowings: [Foreshadowing] = []
    /// 统计基线：最近一次记录起点字数的日期（仅到天）
    @Published public var lastStatsDate: Date?
    /// 统计基线：当天起点总字数（今日新增 = 当前总字数 - 该值）
    @Published public var lastTotalWordCount: Int = 0

    public init(id: UUID = UUID(), title: String, synopsis: String = "") {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Codable（反向引用不入档，解码后重建）

    public enum CodingKeys: String, CodingKey {
        case id, title, synopsis, genre, perspective, styleGuide
        case accentColorHex, enabledTagIDs, r18Enabled, createdAt, updatedAt
        case volumes, characters, worldEntries, chatThreads
        case foreshadowings, lastStatsDate, lastTotalWordCount, activeStyleProfileID, sourceProfileID
    }

    public required init(from decoder: Decoder) throws {
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
        foreshadowings = try c.decodeIfPresent([Foreshadowing].self, forKey: .foreshadowings) ?? []
        lastStatsDate = try c.decodeIfPresent(Date.self, forKey: .lastStatsDate)
        lastTotalWordCount = try c.decodeIfPresent(Int.self, forKey: .lastTotalWordCount) ?? 0
        activeStyleProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeStyleProfileID)
        sourceProfileID = try c.decodeIfPresent(UUID.self, forKey: .sourceProfileID)
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

    public func encode(to encoder: Encoder) throws {
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
        try c.encode(foreshadowings, forKey: .foreshadowings)
        try c.encodeIfPresent(lastStatsDate, forKey: .lastStatsDate)
        try c.encode(lastTotalWordCount, forKey: .lastTotalWordCount)
        try c.encodeIfPresent(activeStyleProfileID, forKey: .activeStyleProfileID)
        try c.encodeIfPresent(sourceProfileID, forKey: .sourceProfileID)
    }
}

public extension Novel {
    /// R18 作品的强制强调色（血红色），开启期间不可修改
    static let r18AccentHex = "#CC0000"
    /// R18 免责说明三段文案（内联确认卡共用）
    static let r18NoticeText = "说明：此功能仅为合规的 R18 写作提示词注入，用于增强小说文采与场景表现力，并非「破甲」或「越狱」提示词。\n提醒：如需更高级别的 R18 内容生成，请自行配置相应模型或 API 权限，本功能不涉及任何绕过模型安全策略的操作。\n免责声明：生成的所有内容均由您自行负责，与本应用开发者及运营方无关。"
}

// MARK: - 卷章纲四维结构（情绪走向 / 冲突阶梯 / 信息差 / 场景卡）
// 方法论参考 awesome-novel-agent 的维度划分，结构为本项目自行设计。

/// 场景卡：本章一个场景的三要素
public struct SceneCard: Codable, Equatable {
    public var goal: String        // 主角这场想达成什么
    public var obstacle: String    // 什么拦着
    public var hook: String        // 什么悬念勾读者往下看

    public init(goal: String = "", obstacle: String = "", hook: String = "") {
        self.goal = goal
        self.obstacle = obstacle
        self.hook = hook
    }

    public var isEmpty: Bool {
        goal.trimmingCharacters(in: .whitespaces).isEmpty
            && obstacle.trimmingCharacters(in: .whitespaces).isEmpty
            && hook.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// 冲突阶梯的一级（核心冲突逐级升高）
public struct ConflictRung: Codable, Equatable {
    public var level: Int              // 层级序号（1 起）
    public var obstacle: String        // 这一级的阻力/对手
    public var turningPoint: String?   // 跨入该层的转折点

    public init(level: Int, obstacle: String, turningPoint: String? = nil) {
        self.level = level
        self.obstacle = obstacle
        self.turningPoint = turningPoint
    }
}

/// 信息差：本卷「谁知道什么」从起点到终点的变化
public struct InfoGap: Codable, Equatable {
    public var start: String           // 卷初读者/主角知道什么
    public var end: String             // 卷末将揭示或颠覆什么

    public var isEmpty: Bool {
        start.trimmingCharacters(in: .whitespaces).isEmpty
            && end.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public init(start: String = "", end: String = "") {
        self.start = start
        self.end = end
    }
}

// MARK: - 伏笔台账（v1.9）
// 跨章跨卷的悬念追踪：摘要建档时 AI 提取新伏笔静默入库，续写时注入临近回收提醒。

public enum ForeshadowStatus: String, Codable {
    case open       // 未回收
    case resolved   // 已回收
    case dropped    // 废弃（作者主动放弃此线）
}

public struct Foreshadowing: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var detail: String?
    public var plantedVolumeIndex: Int?    // 埋设卷序（1-based）
    public var plantedChapterOrder: Int?   // 埋设章序（卷内，1-based）
    public var plannedResolve: String?     // 计划回收位置（自由文本）
    public var status: ForeshadowStatus
    public var note: String?
    /// 摘要提取时标记：LLM 认为本章已回收此条，待作者确认（不自动翻转 status）
    public var suggestedResolved: Bool = false

    public init(id: UUID = UUID(), title: String, detail: String? = nil,
         plantedVolumeIndex: Int? = nil, plantedChapterOrder: Int? = nil,
         plannedResolve: String? = nil, status: ForeshadowStatus = .open,
         note: String? = nil, suggestedResolved: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.plantedVolumeIndex = plantedVolumeIndex
        self.plantedChapterOrder = plantedChapterOrder
        self.plannedResolve = plannedResolve
        self.status = status
        self.note = note
        self.suggestedResolved = suggestedResolved
    }
}

public final class Volume: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var name: String
    @Published public var outline: String?                 // 卷纲
    /// 四维：情绪走向（按节拍，如 压抑→提升→打脸）
    @Published public var emotionArc: [String]?
    /// 四维：冲突阶梯（核心冲突逐级升高）
    @Published public var conflictLadder: [ConflictRung]?
    /// 四维：信息差（卷初谁知道什么 → 卷末揭示什么）
    @Published public var infoGap: InfoGap?
    @Published public var sortOrder: Int
    public weak var novel: Novel?

    @Published public var chapters: [Chapter] = []

    public init(id: UUID = UUID(), name: String, sortOrder: Int, outline: String? = nil) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.outline = outline
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, outline, emotionArc, conflictLadder, infoGap
        case sortOrder, chapters
    }

    public required init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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

public final class Chapter: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var title: String
    @Published public var detailedOutline: String?         // 本章细纲
    /// 场景卡：本章 1-3 个场景的三要素（目标/阻力/钩子）
    @Published public var sceneCards: [SceneCard]?
    @Published public var content: String                  // 正文
    @Published public var sortOrder: Int
    @Published public var wordCount: Int
    @Published public var updatedAt: Date
    public weak var volume: Volume?

    @Published public var snapshots: [ChapterSnapshot] = []
    @Published public var summary: ChapterSummary?

    public init(id: UUID = UUID(), title: String, sortOrder: Int) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.content = ""
        self.wordCount = 0
        self.updatedAt = .now
    }

    public enum CodingKeys: String, CodingKey {
        case id, title, detailedOutline, sceneCards, content, sortOrder, wordCount, updatedAt
        case snapshots, summary
    }

    public required init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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

public final class ChapterSummary: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var summaryText: String              // 本章摘要
    @Published public var keyFacts: [String]               // 关键事实（叙事账本简化版）
    public weak var chapter: Chapter?

    public init(id: UUID = UUID(), summaryText: String, keyFacts: [String] = []) {
        self.id = id
        self.summaryText = summaryText
        self.keyFacts = keyFacts
    }

    public enum CodingKeys: String, CodingKey { case id, summaryText, keyFacts }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        summaryText = try c.decode(String.self, forKey: .summaryText)
        keyFacts = try c.decode([String].self, forKey: .keyFacts)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(summaryText, forKey: .summaryText)
        try c.encode(keyFacts, forKey: .keyFacts)
    }
}

public final class ChapterSnapshot: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var versionNumber: Int
    @Published public var content: String
    @Published public var triggerType: String              // manual_save / ai_insert / restore
    @Published public var createdAt: Date
    public weak var chapter: Chapter?

    public init(id: UUID = UUID(), versionNumber: Int, content: String, triggerType: String) {
        self.id = id
        self.versionNumber = versionNumber
        self.content = content
        self.triggerType = triggerType
        self.createdAt = .now
    }

    public enum CodingKeys: String, CodingKey { case id, versionNumber, content, triggerType, createdAt }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        versionNumber = try c.decode(Int.self, forKey: .versionNumber)
        content = try c.decode(String.self, forKey: .content)
        triggerType = try c.decode(String.self, forKey: .triggerType)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(versionNumber, forKey: .versionNumber)
        try c.encode(content, forKey: .content)
        try c.encode(triggerType, forKey: .triggerType)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

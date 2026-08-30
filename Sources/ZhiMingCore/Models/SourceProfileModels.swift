import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - 扫描枚举与状态

/// 扫描档位：fast=每章双窗采样，full=全章整块
public enum ScanMode: String, Codable { case fast, full }

/// 扫描阶段（进度可视化与断点续传标记）
public enum ScanStage: String, Codable, Equatable { case awaiting, mapping, reducing, styling, done, paused }

/// 事件重要性：蓝图/细纲注入只带 major 全量 + minor 概要，压 token
public enum Importance: String, Codable, Equatable {
    case major, minor
    public var majorRank: Int { self == .major ? 1 : 0 }
}

/// 原书体量与档位元信息
public struct ScanMeta: Codable, Equatable {
    public var totalChapters: Int
    public var totalChars: Int
    public var scanMode: ScanMode
    public init(totalChapters: Int = 0, totalChars: Int = 0, scanMode: ScanMode = .fast) {
        self.totalChapters = totalChapters; self.totalChars = totalChars; self.scanMode = scanMode
    }
}

/// 扫描进度状态（chunk 粒度断点续传 + token 计量，只增不减）
public struct ScanState: Codable, Equatable {
    public var stage: ScanStage
    public var totalChunks: Int
    public var doneChunks: Int
    public var tokensIn: Int
    public var tokensOut: Int
    public var startedAt: Date?
    public init(stage: ScanStage = .awaiting, totalChunks: Int = 0, doneChunks: Int = 0,
                tokensIn: Int = 0, tokensOut: Int = 0, startedAt: Date? = nil) {
        self.stage = stage; self.totalChunks = totalChunks; self.doneChunks = doneChunks
        self.tokensIn = tokensIn; self.tokensOut = tokensOut; self.startedAt = startedAt
    }
    public var isComplete: Bool { stage == .done && totalChunks > 0 && doneChunks >= totalChunks }
}

// MARK: - 原作事实卡（防 OOC 核心资产）

/// 原作角色卡：一张卡一个角色，多阶段变化进 arc（弧光保序防「后期性格写回前期」）
public struct CanonCharacter: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var aliases: [String] = []
    public var role: String?
    public var oneLine: String?
    public var appearance: String?
    public var personality: String?
    public var abilities: String?
    public var relationships: [CanonRelationship] = []
    public var arc: [CanonArc] = []

    public init(name: String, aliases: [String] = [], role: String? = nil, oneLine: String? = nil,
                appearance: String? = nil, personality: String? = nil, abilities: String? = nil) {
        self.name = name; self.aliases = aliases; self.role = role; self.oneLine = oneLine
        self.appearance = appearance; self.personality = personality; self.abilities = abilities
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, aliases, role, oneLine, appearance, personality, abilities, relationships, arc
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        role = try c.decodeIfPresent(String.self, forKey: .role)
        oneLine = try c.decodeIfPresent(String.self, forKey: .oneLine)
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance)
        personality = try c.decodeIfPresent(String.self, forKey: .personality)
        abilities = try c.decodeIfPresent(String.self, forKey: .abilities)
        relationships = try c.decodeIfPresent([CanonRelationship].self, forKey: .relationships) ?? []
        arc = try c.decodeIfPresent([CanonArc].self, forKey: .arc) ?? []
    }
}

/// 角色间关系（父子/师徒/敌对/手足/恋人…）
public struct CanonRelationship: Codable, Equatable {
    public var target: String
    public var relation: String
    public init(target: String, relation: String) {
        self.target = target; self.relation = relation
    }
}

/// 角色在原作某阶段的状态/性格变化（弧光）
public struct CanonArc: Codable, Equatable {
    public var stage: String
    public var change: String
    public init(stage: String, change: String) {
        self.stage = stage; self.change = change
    }
}

/// 原作事件（时间线一条）：phase 分阶段、importance 分级注入、consequence 记不可逆事实
public struct CanonEvent: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var phase: String?
    public var summary: String
    public var participants: [String] = []
    public var importance: Importance = .minor
    public var consequence: String?

    public init(phase: String? = nil, summary: String, participants: [String] = [],
                importance: Importance = .minor, consequence: String? = nil) {
        self.phase = phase; self.summary = summary; self.participants = participants
        self.importance = importance; self.consequence = consequence
    }

    public enum CodingKeys: String, CodingKey {
        case id, phase, summary, participants, importance, consequence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        phase = try c.decodeIfPresent(String.self, forKey: .phase)
        summary = try c.decode(String.self, forKey: .summary)
        participants = try c.decodeIfPresent([String].self, forKey: .participants) ?? []
        importance = try c.decodeIfPresent(Importance.self, forKey: .importance) ?? .minor
        consequence = try c.decodeIfPresent(String.self, forKey: .consequence)
    }
}

/// 世界观条目（地点/势力/规则/物品/力量体系）
public struct CanonWorldEntry: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var category: String
    public var name: String
    public var content: String

    public init(category: String, name: String, content: String) {
        self.category = category; self.name = name; self.content = content
    }

    public enum CodingKeys: String, CodingKey { case id, category, name, content }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "设定"
        name = try c.decode(String.self, forKey: .name)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
    }
}

// MARK: - 原作档案（全局库条目，一本原作一个档案）

/// 同人创作的地基档案：人物/事件/世界观 + 文风绑定 + 扫描状态。
/// Codable 手写 + decodeIfPresent 兜底（合成解码对非可选数组缺 key 会抛 keyNotFound）。
public final class SourceNovelProfile: Identifiable, ObservableObject, Codable, Equatable {
    public let id: UUID
    @Published public var title: String
    @Published public var author: String?
    @Published public var createdAt: Date
    @Published public var meta: ScanMeta
    @Published public var characters: [CanonCharacter] = []
    @Published public var timeline: [CanonEvent] = []
    @Published public var worldbuilding: [CanonWorldEntry] = []
    @Published public var styleProfileID: UUID?
    @Published public var scanState: ScanState

    public init(id: UUID = UUID(), title: String, author: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.createdAt = .now
        self.meta = ScanMeta()
        self.scanState = ScanState()
    }

    public enum CodingKeys: String, CodingKey {
        case id, title, author, createdAt, meta, characters, timeline, worldbuilding, styleProfileID, scanState
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "未命名原作"
        author = try c.decodeIfPresent(String.self, forKey: .author)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        meta = try c.decodeIfPresent(ScanMeta.self, forKey: .meta) ?? ScanMeta()
        characters = try c.decodeIfPresent([CanonCharacter].self, forKey: .characters) ?? []
        timeline = try c.decodeIfPresent([CanonEvent].self, forKey: .timeline) ?? []
        worldbuilding = try c.decodeIfPresent([CanonWorldEntry].self, forKey: .worldbuilding) ?? []
        styleProfileID = try c.decodeIfPresent(UUID.self, forKey: .styleProfileID)
        scanState = try c.decodeIfPresent(ScanState.self, forKey: .scanState) ?? ScanState()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(author, forKey: .author)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(meta, forKey: .meta)
        try c.encode(characters, forKey: .characters)
        try c.encode(timeline, forKey: .timeline)
        try c.encode(worldbuilding, forKey: .worldbuilding)
        try c.encodeIfPresent(styleProfileID, forKey: .styleProfileID)
        try c.encode(scanState, forKey: .scanState)
    }

    public static func == (l: SourceNovelProfile, r: SourceNovelProfile) -> Bool { l.id == r.id }
}

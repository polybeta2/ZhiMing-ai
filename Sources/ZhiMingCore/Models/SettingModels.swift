import Foundation
#if canImport(Combine)
import Combine
#endif

public final class CharacterCard: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var name: String
    @Published public var aliases: [String]
    @Published public var appearance: String?
    @Published public var personality: String?
    @Published public var background: String?
    @Published public var currentGoal: String?
    @Published public var currentLocation: String?
    @Published public var physicalState: String?
    @Published public var mentalState: String?
    @Published public var lastSeenChapterTitle: String?
    @Published public var isSceneRelevant: Bool            // 是否参与近期剧情（续写时优先进上下文）
    public weak var novel: Novel?

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.aliases = []
        self.isSceneRelevant = true
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, aliases, appearance, personality, background
        case currentGoal, currentLocation, physicalState, mentalState
        case lastSeenChapterTitle, isSceneRelevant
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decode([String].self, forKey: .aliases)
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance)
        personality = try c.decodeIfPresent(String.self, forKey: .personality)
        background = try c.decodeIfPresent(String.self, forKey: .background)
        currentGoal = try c.decodeIfPresent(String.self, forKey: .currentGoal)
        currentLocation = try c.decodeIfPresent(String.self, forKey: .currentLocation)
        physicalState = try c.decodeIfPresent(String.self, forKey: .physicalState)
        mentalState = try c.decodeIfPresent(String.self, forKey: .mentalState)
        lastSeenChapterTitle = try c.decodeIfPresent(String.self, forKey: .lastSeenChapterTitle)
        isSceneRelevant = try c.decode(Bool.self, forKey: .isSceneRelevant)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(aliases, forKey: .aliases)
        try c.encodeIfPresent(appearance, forKey: .appearance)
        try c.encodeIfPresent(personality, forKey: .personality)
        try c.encodeIfPresent(background, forKey: .background)
        try c.encodeIfPresent(currentGoal, forKey: .currentGoal)
        try c.encodeIfPresent(currentLocation, forKey: .currentLocation)
        try c.encodeIfPresent(physicalState, forKey: .physicalState)
        try c.encodeIfPresent(mentalState, forKey: .mentalState)
        try c.encodeIfPresent(lastSeenChapterTitle, forKey: .lastSeenChapterTitle)
        try c.encode(isSceneRelevant, forKey: .isSceneRelevant)
    }
}

public final class WorldEntry: Identifiable, ObservableObject, Codable {
    /// 世界观分类全集。原在 WorldListView，因 AssistantPatch 落库校验需要移入 Core
    public static let categories = ["地点", "势力", "规则", "物品", "其他"]

    public let id: UUID
    @Published public var category: String                 // 地点 / 势力 / 规则 / 物品 / 其他
    @Published public var name: String
    @Published public var content: String
    public weak var novel: Novel?

    public init(id: UUID = UUID(), category: String, name: String, content: String = "") {
        self.id = id
        self.category = category
        self.name = name
        self.content = content
    }

    public enum CodingKeys: String, CodingKey { case id, category, name, content }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        category = try c.decode(String.self, forKey: .category)
        name = try c.decode(String.self, forKey: .name)
        content = try c.decode(String.self, forKey: .content)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(category, forKey: .category)
        try c.encode(name, forKey: .name)
        try c.encode(content, forKey: .content)
    }
}

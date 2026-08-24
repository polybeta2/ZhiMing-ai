import Foundation
import Combine

final class CharacterCard: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var aliases: [String]
    @Published var appearance: String?
    @Published var personality: String?
    @Published var background: String?
    @Published var currentGoal: String?
    @Published var currentLocation: String?
    @Published var physicalState: String?
    @Published var mentalState: String?
    @Published var lastSeenChapterTitle: String?
    @Published var isSceneRelevant: Bool            // 是否参与近期剧情（续写时优先进上下文）
    weak var novel: Novel?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.aliases = []
        self.isSceneRelevant = true
    }

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, appearance, personality, background
        case currentGoal, currentLocation, physicalState, mentalState
        case lastSeenChapterTitle, isSceneRelevant
    }

    required init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

final class WorldEntry: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var category: String                 // 地点 / 势力 / 规则 / 物品 / 其他
    @Published var name: String
    @Published var content: String
    weak var novel: Novel?

    init(id: UUID = UUID(), category: String, name: String, content: String = "") {
        self.id = id
        self.category = category
        self.name = name
        self.content = content
    }

    enum CodingKeys: String, CodingKey { case id, category, name, content }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        category = try c.decode(String.self, forKey: .category)
        name = try c.decode(String.self, forKey: .name)
        content = try c.decode(String.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(category, forKey: .category)
        try c.encode(name, forKey: .name)
        try c.encode(content, forKey: .content)
    }
}

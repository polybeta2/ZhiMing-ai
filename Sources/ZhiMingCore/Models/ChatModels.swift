import Foundation
#if canImport(Combine)
import Combine
#endif

public final class ChatThread: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var purpose: String                  // creation（立项）/ writing（写作助手）
    @Published public var createdAt: Date
    /// 完整思路立项：跳过澄清问答，进入对话直接规划卷章结构
    @Published public var skipsClarification: Bool = false
    public weak var novel: Novel?

    @Published public var messages: [ChatMessage] = []

    public init(id: UUID = UUID(), purpose: String) {
        self.id = id
        self.purpose = purpose
        self.createdAt = .now
    }

    public enum CodingKeys: String, CodingKey { case id, purpose, createdAt, skipsClarification, messages }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        purpose = try c.decode(String.self, forKey: .purpose)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        skipsClarification = try c.decodeIfPresent(Bool.self, forKey: .skipsClarification) ?? false
        messages = try c.decode([ChatMessage].self, forKey: .messages)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(purpose, forKey: .purpose)
        try c.encode(createdAt, forKey: .createdAt)
        if skipsClarification { try c.encode(true, forKey: .skipsClarification) }
        try c.encode(messages, forKey: .messages)
    }
}

public final class ChatMessage: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var role: String                     // user / assistant
    @Published public var content: String
    @Published public var createdAt: Date
    public weak var thread: ChatThread?

    public init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = .now
    }

    public enum CodingKeys: String, CodingKey { case id, role, content, createdAt }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(role, forKey: .role)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

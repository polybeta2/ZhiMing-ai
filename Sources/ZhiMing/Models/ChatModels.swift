import Foundation
import Combine

final class ChatThread: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var purpose: String                  // creation（立项）/ writing（写作助手）
    @Published var createdAt: Date
    /// 完整思路立项：跳过澄清问答，进入对话直接规划卷章结构
    @Published var skipsClarification: Bool = false
    weak var novel: Novel?

    @Published var messages: [ChatMessage] = []

    init(id: UUID = UUID(), purpose: String) {
        self.id = id
        self.purpose = purpose
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, purpose, createdAt, skipsClarification, messages }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        purpose = try c.decode(String.self, forKey: .purpose)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        skipsClarification = try c.decodeIfPresent(Bool.self, forKey: .skipsClarification) ?? false
        messages = try c.decode([ChatMessage].self, forKey: .messages)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(purpose, forKey: .purpose)
        try c.encode(createdAt, forKey: .createdAt)
        if skipsClarification { try c.encode(true, forKey: .skipsClarification) }
        try c.encode(messages, forKey: .messages)
    }
}

final class ChatMessage: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var role: String                     // user / assistant
    @Published var content: String
    @Published var createdAt: Date
    weak var thread: ChatThread?

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, role, content, createdAt }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(role, forKey: .role)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

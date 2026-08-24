import Foundation
import Observation

@Observable
final class ChatThread: Identifiable, Codable {
    let id: UUID
    var purpose: String                  // creation（立项）/ writing（写作助手）
    var createdAt: Date
    @ObservationIgnored weak var novel: Novel?

    var messages: [ChatMessage] = []

    init(id: UUID = UUID(), purpose: String) {
        self.id = id
        self.purpose = purpose
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, purpose, createdAt, messages }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        purpose = try c.decode(String.self, forKey: .purpose)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        messages = try c.decode([ChatMessage].self, forKey: .messages)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(purpose, forKey: .purpose)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(messages, forKey: .messages)
    }
}

@Observable
final class ChatMessage: Identifiable, Codable {
    let id: UUID
    var role: String                     // user / assistant
    var content: String
    var createdAt: Date
    @ObservationIgnored weak var thread: ChatThread?

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = .now
    }

    enum CodingKeys: String, CodingKey { case id, role, content, createdAt }

    init(from decoder: Decoder) throws {
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

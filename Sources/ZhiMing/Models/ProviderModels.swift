import Foundation
import Observation

@Observable
final class ProviderConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var baseUrl: String                  // 如 https://api.openai.com/v1
    var apiKeyID: String                 // Keychain 账户键（不存明文）
    var modelName: String
    var temperature: Double
    var maxTokens: Int                   // 输出预留
    var contextBudgetChars: Int          // 输入上下文字符预算
    var systemPromptExtra: String?       // 用户附加系统指令
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, baseUrl: String, modelName: String) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeyID = UUID().uuidString
        self.modelName = modelName
        self.temperature = 0.8
        self.maxTokens = 4096
        self.contextBudgetChars = 12000
        self.isDefault = false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, baseUrl, apiKeyID, modelName, temperature
        case maxTokens, contextBudgetChars, systemPromptExtra, isDefault
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        baseUrl = try c.decode(String.self, forKey: .baseUrl)
        apiKeyID = try c.decode(String.self, forKey: .apiKeyID)
        modelName = try c.decode(String.self, forKey: .modelName)
        temperature = try c.decode(Double.self, forKey: .temperature)
        maxTokens = try c.decode(Int.self, forKey: .maxTokens)
        contextBudgetChars = try c.decode(Int.self, forKey: .contextBudgetChars)
        systemPromptExtra = try c.decodeIfPresent(String.self, forKey: .systemPromptExtra)
        isDefault = try c.decode(Bool.self, forKey: .isDefault)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(baseUrl, forKey: .baseUrl)
        try c.encode(apiKeyID, forKey: .apiKeyID)
        try c.encode(modelName, forKey: .modelName)
        try c.encode(temperature, forKey: .temperature)
        try c.encode(maxTokens, forKey: .maxTokens)
        try c.encode(contextBudgetChars, forKey: .contextBudgetChars)
        try c.encodeIfPresent(systemPromptExtra, forKey: .systemPromptExtra)
        try c.encode(isDefault, forKey: .isDefault)
    }
}

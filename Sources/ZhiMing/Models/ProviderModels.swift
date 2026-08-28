import Foundation
import Combine

final class ProviderConfig: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var baseUrl: String                  // 如 https://api.openai.com/v1
    @Published var apiKeyID: String                 // Keychain 账户键（不存明文）
    @Published var modelName: String
    @Published var temperature: Double
    @Published var maxTokens: Int                   // 输出预留
    @Published var contextBudgetChars: Int          // 输入上下文字符预算
    @Published var systemPromptExtra: String?       // 用户附加系统指令
    @Published var isDefault: Bool

    init(id: UUID = UUID(), name: String, baseUrl: String, modelName: String) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeyID = UUID().uuidString
        self.modelName = modelName
        self.temperature = 0.8
        self.maxTokens = 16384          // 现代模型默认输出预算（蓝图/细纲 JSON 很长，4096 必截断）
        self.contextBudgetChars = 60000 // 现代模型普遍 200K+ 上下文，输入默认放宽到 6 万字符
        self.isDefault = false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, baseUrl, apiKeyID, modelName, temperature
        case maxTokens, contextBudgetChars, systemPromptExtra, isDefault
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        baseUrl = try c.decode(String.self, forKey: .baseUrl)
        apiKeyID = try c.decode(String.self, forKey: .apiKeyID)
        modelName = try c.decode(String.self, forKey: .modelName)
        temperature = try c.decode(Double.self, forKey: .temperature)
        let decodedMax = try c.decode(Int.self, forKey: .maxTokens)
        let decodedBudget = try c.decode(Int.self, forKey: .contextBudgetChars)
        systemPromptExtra = try c.decodeIfPresent(String.self, forKey: .systemPromptExtra)
        isDefault = try c.decode(Bool.self, forKey: .isDefault)
        // 旧出厂默认迁移：v1.x 时代出厂为 4096/12000，蓝图/细纲 JSON 输出必被截断。
        // 仅当字段「恰好等于旧出厂默认」时提升到新默认，用户手动调整过的值不动。
        maxTokens = decodedMax == 4096 ? 16384 : decodedMax          // v1.x 出厂默认 → 新默认
        contextBudgetChars = decodedBudget == 12000 ? 60000 : decodedBudget
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

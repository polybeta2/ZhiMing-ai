import Foundation

struct LLMMessage: Hashable {
    enum Role: String { case system, user, assistant }
    let role: Role
    let content: String
}

struct GenerationConfig {
    var temperature: Double
    var maxTokens: Int
}

enum LLMError: LocalizedError {
    case invalidURL
    case httpStatus(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "接口地址无效"
        case .httpStatus(let code, let body): return "请求失败（\(code)）：\(body.prefix(200))"
        case .decoding(let raw): return "响应解析失败：\(raw.prefix(200))"
        }
    }
}

protocol LLMClient {
    func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<String, Error>
    func testConnection() async throws -> String
}

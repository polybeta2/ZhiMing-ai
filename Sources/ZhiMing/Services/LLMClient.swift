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
        // 先脱敏再截断：部分网关会把 Authorization 回显进错误页
        case .httpStatus(let code, let body): return "请求失败（\(code)）：\(Self.redacted(body).prefix(200))"
        case .decoding(let raw): return "响应解析失败：\(Self.redacted(raw).prefix(200))"
        }
    }

    /// 抹掉错误文本中可能被回显的 Bearer 凭据片段
    private static func redacted(_ raw: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"Bearer\s+\S+"#, options: [.caseInsensitive]) else { return raw }
        let range = NSRange(raw.startIndex..., in: raw)
        return regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: "Bearer ***")
    }
}

/// 流式事件：思维链（reasoning_content）与正文分开通道
enum StreamEvent {
    case reasoning(String)
    case content(String)
}

protocol LLMClient {
    func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamEvent, Error>
    func testConnection() async throws -> String
}

extension Array where Element == LLMMessage {
    /// 全部消息 content 的字符总数（体量护栏与预算扣减共用）
    var totalContentChars: Int { reduce(0) { $0 + $1.content.count } }
}

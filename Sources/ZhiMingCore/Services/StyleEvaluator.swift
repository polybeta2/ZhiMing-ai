import Foundation

/// 风格体检结果（字段对应 prompt.style.eval 模板；全部可缺失容错）
public struct StyleEvalResult: Decodable {
    public var overall: Int?
    public var scores: [DimensionScore]?
    public var drifts: [String]?
    public var ai_flavor: [String]?
    public var moves: [String]?

    public struct DimensionScore: Decodable {
        public var dimension: String?
        public var score: Int?
        public var note: String?
    }
}

public enum StyleEvalError: LocalizedError {
    case parseFailed

    public var errorDescription: String? {
        "体检结果 JSON 解析失败，请重试或更换模型"
    }
}

/// 风格体检（P2）：草稿对照文风档案基准逐维打分 + 漂移点/AI 腔/修改动作。
/// 单次 LLM 调用；LLMClient 注入，Linux XCTest 可测。
public final class StyleEvaluator {
    private let client: LLMClient
    private let config: GenerationConfig

    public init(client: LLMClient, config: GenerationConfig) {
        self.client = client
        self.config = config
    }

    /// - Parameters:
    ///   - draft: 待体检草稿（整章或选段）
    ///   - localReport: ProseChecker 本地快检报告（可选，并入基准输入）
    public func evaluate(draft: String, draftTitle: String,
                         localReport: String?,
                         evalSystem: String, evalCard: String) async throws -> StyleEvalResult {
        var user = "【体检基准】\n\(evalCard)"
        if let report = localReport?.trimmingCharacters(in: .whitespacesAndNewlines), !report.isEmpty {
            user += "\n\n【本地体检结果】\n\(report)"
        }
        user += "\n\n【草稿·\(draftTitle)】\n\(draft)"

        var accumulated = ""
        for try await event in client.streamChat(
            messages: [.init(role: .system, content: evalSystem),
                       .init(role: .user, content: user)],
            config: config) {
            if case .content(let delta) = event { accumulated += delta }
        }
        guard let result = LLMJSONParser.decode(StyleEvalResult.self, fromJSONObjectIn: accumulated) else {
            throw StyleEvalError.parseFailed
        }
        return result
    }
}

import Foundation

/// OpenAI 兼容 SSE 流式客户端（对标 Kelivo sse_framing/sse_decode_loop 的简化版）
final class OpenAICompatibleClient: LLMClient {
    private let baseUrl: URL
    private let apiKey: String
    private let model: String

    init(baseUrl: URL, apiKey: String, model: String) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.model = model
    }

    func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(messages: messages, config: config)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw LLMError.invalidURL }
                    guard http.statusCode == 200 else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw LLMError.httpStatus(http.statusCode, body)
                    }
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let delta = Self.extractDelta(payload) {
                            if !delta.isEmpty { continuation.yield(delta) }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async throws -> String {
        var iterator = streamChat(
            messages: [LLMMessage(role: .user, content: "回复“连接成功”四个字")],
            config: GenerationConfig(temperature: 0, maxTokens: 32)
        ).makeAsyncIterator()
        var text = ""
        while let delta = try await iterator.next() { text += delta }
        return text
    }

    private func makeRequest(messages: [LLMMessage], config: GenerationConfig) throws -> URLRequest {
        let url = baseUrl.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func extractDelta(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else { return nil }
        return delta["content"] as? String
    }
}

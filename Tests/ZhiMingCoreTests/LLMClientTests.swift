import XCTest
@testable import ZhiMingCore

/// LLMClient 协议契约（Mock 重放）与消息辅助计算
final class LLMClientTests: XCTestCase {

    /// 协议测试替身：按脚本重放事件序列（真实流式链路的行为参照）
    struct MockLLMClient: LLMClient {
        var script: [StreamEvent]

        public func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamEvent, Error> {
            let script = self.script
            return AsyncThrowingStream { continuation in
                let task = Task {
                    for event in script {
                        try Task.checkCancellation()
                        continuation.yield(event)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        public func testConnection() async throws -> String {
            "mock-ok"
        }
    }

    func testStreamReplayOrderAndContent() async throws {
        let client = MockLLMClient(script: [
            .reasoning("思考一"),
            .reasoning("思考二"),
            .content("第一段"),
            .content("第二段"),
        ])
        var events: [StreamEvent] = []
        for try await event in client.streamChat(messages: [], config: GenerationConfig(temperature: 0.7, maxTokens: 100)) {
            events.append(event)
        }
        XCTAssertEqual(events.count, 4)
        if case .reasoning(let text) = events[0] { XCTAssertEqual(text, "思考一") }
        if case .content(let text) = events[2] { XCTAssertEqual(text, "第一段") }
        let content = events.compactMap { if case .content(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(content.joined(), "第一段第二段")
    }

    func testTotalContentChars() {
        let messages: [LLMMessage] = [
            .init(role: .system, content: "1234"),
            .init(role: .user, content: "567890"),
        ]
        XCTAssertEqual(messages.totalContentChars, 10)
    }

    func testGenerationConfigValuesRoundtripInStruct() {
        var config = GenerationConfig(temperature: 0.9, maxTokens: 16_384)
        config.temperature = 1.2
        XCTAssertEqual(config.maxTokens, 16_384)
        XCTAssertEqual(config.temperature, 1.2, accuracy: 0.0001)
    }
}

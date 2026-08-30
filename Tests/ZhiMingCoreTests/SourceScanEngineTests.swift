import XCTest
@testable import ZhiMingCore

final class SourceScanEngineTests: XCTestCase {

    /// Mock LLM：按脚本逐次返回 content；stream 幂等
    private final class MockLLM: LLMClient {
        var replies: [String]
        var callCount = 0
        init(_ replies: [String]) { self.replies = replies }
        func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamEvent, Error> {
            AsyncThrowingStream { cont in
                let reply = self.callCount < self.replies.count ? self.replies[self.callCount] : "{}"
                self.callCount += 1
                cont.yield(.content(reply)); cont.finish()
            }
        }
        func testConnection() async throws -> String { "mock-ok" }
    }

    /// 3 章快扫 → 3 块微摘要（每块固定）→ 断点存 doneIds；恢复时只重跑 pending
    func testResumeSkipsDoneChunks() async throws {
        let text = (1...3).map { "第\($0)章 章\($0)\n" + String(repeating: "内\($0)", count: 500) }.joined(separator: "\n")
        let chunker = SourceScanChunker.chunks(from: text, mode: .fast)
        XCTAssertEqual(chunker.count, 3)
        let microJSON = #"{"characters":[],"events":[{"summary":"e","participants":[]}],"worldbuilding":[]}"#

        var doneIDs: Set<Int> = []
        var requested: [Int] = []
        let engine = SourceScanEngine(
            chunks: chunker,
            client: MockLLM([microJSON, microJSON, microJSON]),
            mode: .fast,
            doneChunkIDs: doneIDs,
            onChunkRequest: { idx, _ in doneIDs.insert(idx); requested.append(idx) }
        )
        var events: [Int] = []
        for try await ev in engine.run() {
            if case .chunkDone(let idx) = ev { events.append(idx) }
        }
        XCTAssertEqual(events, [0, 1, 2])

        // 恢复：doneIDs={0,1} → 只跑 2
        doneIDs = [0, 1]
        let done = doneIDs
        requested = []
        let engine2 = SourceScanEngine(
            chunks: chunker, client: MockLLM([microJSON]),
            mode: .fast, doneChunkIDs: done,
            onChunkRequest: { idx, _ in requested.append(idx) }
        )
        for try await ev in engine2.run() { _ = ev }
        XCTAssertEqual(requested, [2])
    }

    /// 事件流包含 phase 与 token 统计（流式可视化依据）
    func testEventPhasesEmitted() async throws {
        let text = "第1章 一\n" + String(repeating: "内容", count: 300) + "\n第2章 二\n" + String(repeating: "内容", count: 300)
        let engine = SourceScanEngine(
            chunks: SourceScanChunker.chunks(from: text, mode: .fast),
            client: MockLLM([#"[{"tokens":5}]"#]),
            mode: .fast, doneChunkIDs: [],
            onChunkRequest: { _, _ in }
        )
        var phases: [SourceScanPhase] = []
        var sawToken = false
        var profile: SourceNovelProfile?
        for try await ev in engine.run() {
            switch ev {
            case .phase(let p): phases.append(p)
            case .tokenUsage: sawToken = true
            case .completed(let p): profile = p
            default: break
            }
        }
        XCTAssertTrue(phases.contains(.mapping))
        XCTAssertTrue(phases.contains(.reducing))
        XCTAssertTrue(phases.contains(.done))
        XCTAssertTrue(sawToken)
        XCTAssertNotNil(profile)
    }
}
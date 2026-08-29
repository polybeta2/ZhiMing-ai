import XCTest
@testable import ZhiMingCore

/// 顺序回放预置响应的 mock 客户端：每个响应作为一个 content 事件发出
final class MockLLMClient: LLMClient {
    var responses: [String]
    private(set) var requestCount = 0

    init(responses: [String]) { self.responses = responses }

    func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamEvent, Error> {
        let response = requestCount < responses.count ? responses[requestCount] : ""
        requestCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(.content(response))
            continuation.finish()
        }
    }

    func testConnection() async throws -> String { "mock" }
}

final class StyleDistillationServiceTests: XCTestCase {
    private let sourceText = String(repeating: "夜色像一块浸了水的绒布压在巷口。他说：「走吧。」脚步声散进雨里。", count: 40)

    private lazy var analysisJSON = """
    ```json
    {"narrative_voice":{"pov":"第三人称贴身","temperature":"冷峻克制","camera_habits":["先给动作再给环境"]},
     "sentence_syntax":{"shape":"短句主导","long_short_ratio":"约2:1，短句收尾","signature_moves":"三连短句，动词开路"},
     "diction":{"register":"口语书面混合","lexical_fields":"雨夜,巷子,旧物","banned_moves":"瞳孔地震"},
     "scene_rhythm":{"openings":"直接进入动作"},"dialogue":{"subtext_level":"高潜台词","tag_habits":"少用说道"},
     "emotion":{"directness":"移置不直陈","preferred_carriers":"动作,物件"},
     "anti_ai":{"forbidden_patterns":["不是…而是…说明腔"],"revision_checks":["检查句长均一"]},
     "evidence":[{"trait":"短句收尾制造顿挫","snippet":"脚步声散进雨里。","confidence":"high"}]}
    ```
    """

    private lazy var cardJSON = """
    {"name":"冷雨短句","tags":"冷峻,白描,都市夜色","fingerprint_summary":"短句主导，情绪移置于物件。",
     "must_rules":"每段至多一个比喻,连续三句不超过15字",
     "avoid_rules":"禁止排比抒情",
     "examples":[{"plain":"他很生气地把门关上了","styled":"门被甩上，震得墙皮簌簌落灰","principle":"情绪外化为声响"}]}
    """

    func testFullPipelineProducesProfile() async throws {
        let client = MockLLMClient(responses: [analysisJSON, cardJSON])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))
        var phases: [StyleDistillPhase] = []
        var profile: StyleProfile?

        for try await event in service.events(sourceText: sourceText, sourceNote: "《测试样本》",
                                              analyzeSystem: "分析", cardSystem: "汇总", fixSystem: "修正") {
            switch event {
            case .phase(let p): phases.append(p)
            case .stream: break
            case .completed(let p): profile = p
            }
        }

        XCTAssertEqual(phases, [.measuring, .analyzing, .buildingCard, .checking])
        let result = try XCTUnwrap(profile)
        XCTAssertEqual(result.name, "冷雨短句")
        XCTAssertEqual(result.tags, ["冷峻", "白描", "都市夜色"])
        XCTAssertEqual(result.mustRules.count, 2)
        XCTAssertEqual(result.narrativeVoice.temperature, "冷峻克制")
        XCTAssertEqual(result.sentenceSyntax.signatureMoves, ["三连短句", "动词开路"], "字符串形态的数组字段应被 FlexStringArray 切分容错")
        XCTAssertEqual(result.diction.bannedMoves, ["瞳孔地震"])
        XCTAssertEqual(result.emotion.preferredCarriers, ["动作", "物件"])
        XCTAssertEqual(result.evidence.first?.snippet, "脚步声散进雨里。")
        XCTAssertEqual(result.confidence, "medium")
        XCTAssertNotNil(result.localMetrics)
        XCTAssertGreaterThan(result.localMetrics!.sentenceCount, 0)
        XCTAssertEqual(client.requestCount, 2, "无违规时只需两次 LLM 调用")
    }

    func testViolationTriggersFixThenKeepsCleanExample() async throws {
        // styled 含与原文 8 字以上连续重合（归一化后）→ S4 触发修正请求；修正结果干净 → 保留，共 3 次调用
        let violatingCard = """
        {"name":"冷雨短句","tags":["冷峻"],"fingerprint_summary":"短句。",
         "must_rules":["短句为主"],"avoid_rules":["排比"],
         "examples":[{"plain":"他很平静","styled":"他说：「走吧。」脚步声散进雨里。","principle":"环境收束"}]}
        """
        let fixJSON = #"[{"index":0,"styled":"巷子把最后一串脚步咽了下去","principle":"环境收束"}]"#
        let client = MockLLMClient(responses: [analysisJSON, violatingCard, fixJSON])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))
        var profile: StyleProfile?
        for try await event in service.events(sourceText: sourceText, sourceNote: "《测试样本》",
                                              analyzeSystem: "分析", cardSystem: "汇总", fixSystem: "修正") {
            if case .completed(let p) = event { profile = p }
        }
        let result = try XCTUnwrap(profile)
        XCTAssertEqual(result.examples.first?.styled, "巷子把最后一串脚步咽了下去")
        XCTAssertEqual(client.requestCount, 3)
    }

    func testUnfixableViolationIsDroppedAndConfidenceLowered() async throws {
        // 修正响应仍然违规（归一化后 ≥8 字与原文连续重合）→ 该示例被丢弃，confidence 降为 low
        let violatingCard = """
        {"name":"冷雨短句","tags":["冷峻"],"fingerprint_summary":"短句。",
         "must_rules":["短句为主"],"avoid_rules":["排比"],
         "examples":[{"plain":"他很平静","styled":"他说：「走吧。」脚步声散进雨里。","principle":"环境收束"}]}
        """
        let badFix = #"[{"index":0,"styled":"夜色像一块浸了水的绒布","principle":"环境收束"}]"#
        let client = MockLLMClient(responses: [analysisJSON, violatingCard, badFix])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))
        var profile: StyleProfile?
        for try await event in service.events(sourceText: sourceText, sourceNote: "《测试样本》",
                                              analyzeSystem: "分析", cardSystem: "汇总", fixSystem: "修正") {
            if case .completed(let p) = event { profile = p }
        }
        let result = try XCTUnwrap(profile)
        XCTAssertTrue(result.examples.isEmpty)
        XCTAssertEqual(result.confidence, "low")
    }

    func testParseFailureThrows() async {
        let client = MockLLMClient(responses: ["这不是JSON", cardJSON])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))
        do {
            for try await _ in service.events(sourceText: sourceText, sourceNote: "x",
                                              analyzeSystem: "a", cardSystem: "b", fixSystem: "c") {}
            XCTFail("应当抛出解析错误")
        } catch { /* 预期路径 */ }
    }
}

import XCTest
@testable import ZhiMingCore

/// P2 风格体检：eval variant 渲染 + 单次评估调用
final class StyleEvalTests: XCTestCase {
    private func makeProfile() -> StyleProfile {
        let p = StyleProfile(name: "冷雨短句")
        p.fingerprintSummary = "短句主导，情绪移置于物件。"
        p.mustRules = ["每段至多一个比喻"]
        p.narrativeVoice.temperature = "冷峻"
        p.sentenceSyntax.longShortRatio = "约2:1"
        p.diction.register = "口语书面混合"
        p.sceneRhythm.openings = "直接入戏"
        p.dialogue.subtextLevel = "高潜台词"
        p.emotion.directness = "移置不直陈"
        p.antiAI.revisionChecks = ["检查句长均一"]
        return p
    }

    func testEvalVariantRendersFullRubric() {
        let card = StyleCardRenderer.render(makeProfile(), variant: .eval)
        XCTAssertTrue(card.contains("风格体检基准"))
        XCTAssertTrue(card.contains("短句主导"))
        XCTAssertTrue(card.contains("必遵规则"))
        XCTAssertTrue(card.contains("检查句长均一"), "自检清单纳入体检基准")
        XCTAssertTrue(card.contains("冷峻"), "全层明细纳入基准")
        XCTAssertLessThanOrEqual(card.count, PromptLimits.styleProfileEvalCap)
    }

    func testEvaluatorParsesScoredResult() async throws {
        let raw = """
        ```json
        {"overall": 7,
         "scores": [
           {"dimension": "叙事声音", "score": 8, "note": "距离贴合"},
           {"dimension": "句法节奏", "score": 6, "note": "长句偏多"},
           {"dimension": "词汇质地", "score": 7, "note": "语域一致"},
           {"dimension": "场景节奏", "score": 7, "note": "开场利落"},
           {"dimension": "对白", "score": 8, "note": "潜台词足"},
           {"dimension": "情绪处理", "score": 6, "note": "偶有直陈"},
           {"dimension": "反AI抵抗力", "score": 7, "note": "无说明腔"}
         ],
         "drifts": ["第三章抒情段偏离冷峻基调"],
         "ai_flavor": ["「他感到一阵莫名的心悸」"],
         "moves": ["把情绪直陈改为物件反应"]}
        ```
        """
        let client = MockLLMClient(responses: [raw])
        let evaluator = StyleEvaluator(client: client, config: GenerationConfig(temperature: 0.2, maxTokens: 4096))
        let result = try await evaluator.evaluate(
            draft: "草稿正文。", draftTitle: "第一章",
            localReport: "- 比喻滥用：「仿佛」出现 3 次",
            evalSystem: "体检", evalCard: "【体检基准】")
        XCTAssertEqual(result.overall, 7)
        let scores = try XCTUnwrap(result.scores)
        XCTAssertEqual(scores.count, 7)
        XCTAssertEqual(scores.first?.dimension, "叙事声音")
        XCTAssertEqual(scores.first?.score, 8)
        XCTAssertEqual(result.drifts, ["第三章抒情段偏离冷峻基调"])
        XCTAssertEqual(result.ai_flavor?.count, 1)
        XCTAssertEqual(result.moves, ["把情绪直陈改为物件反应"])
        XCTAssertEqual(client.requestCount, 1, "体检为单次调用")
    }

    func testEvaluatorThrowsOnBadJSON() async {
        let client = MockLLMClient(responses: ["不是JSON"])
        let evaluator = StyleEvaluator(client: client, config: GenerationConfig(temperature: 0.2, maxTokens: 4096))
        do {
            _ = try await evaluator.evaluate(draft: "x", draftTitle: "t",
                                             localReport: nil, evalSystem: "s", evalCard: "c")
            XCTFail("应当抛出解析错误")
        } catch { /* 预期路径 */ }
    }
}

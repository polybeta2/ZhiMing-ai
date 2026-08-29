import XCTest
@testable import ZhiMingCore

final class StyleAugmentTests: XCTestCase {
    private func makeExisting() -> StyleProfile {
        let p = StyleProfile(name: "冷雨短句", sourceNote: "《原样本》", sampleCharCount: 10_000)
        p.tags = ["冷峻", "白描"]
        p.fingerprintSummary = "短句主导。"
        p.mustRules = ["短句为主", "每段至多一个比喻"]
        p.avoidRules = ["禁止排比"]
        p.narrativeVoice.temperature = "冷峻克制"
        p.narrativeVoice.pov = "第三人称贴身"
        p.emotion.preferredCarriers = ["动作"]
        return p
    }

    private func makeFresh() -> StyleProfile {
        let p = StyleProfile(name: "新名字（忽略）", sourceNote: "《新样本》", sampleCharCount: 5_000)
        p.tags = ["白描", "都市夜色"]
        p.fingerprintSummary = "短句主导，雨夜意象密集。"
        p.mustRules = ["每段至多一个比喻", "连续三句不超过15字"]
        p.narrativeVoice.temperature = "冷峻中带倦意"
        p.narrativeVoice.pov = ""   // 空值：不应覆盖旧值
        p.emotion.preferredCarriers = ["物件"]
        p.examples = [StyleExample(plain: "他很累", styled: "咖啡凉到第三口才想起来喝", principle: "物件承载状态")]
        return p
    }

    func testMergeOverwritesNonEmptyAndKeepsOldForEmpty() {
        let existing = makeExisting()
        StyleProfileAugment.merge(existing: existing, fresh: makeFresh(), reason: "追加样本《新样本》")

        XCTAssertEqual(existing.narrativeVoice.temperature, "冷峻中带倦意")
        XCTAssertEqual(existing.narrativeVoice.pov, "第三人称贴身", "新值为空不覆盖旧值")
        XCTAssertEqual(existing.fingerprintSummary, "短句主导，雨夜意象密集。")
    }

    func testMergeUnionsListsWithDedup() {
        let existing = makeExisting()
        StyleProfileAugment.merge(existing: existing, fresh: makeFresh(), reason: "追加")

        XCTAssertEqual(existing.tags, ["冷峻", "白描", "都市夜色"])
        XCTAssertEqual(existing.mustRules, ["短句为主", "每段至多一个比喻", "连续三句不超过15字"])
        XCTAssertEqual(existing.emotion.preferredCarriers, ["动作", "物件"])
    }

    func testMergeReplacesSampleScopedDataAndSumsCharCount() {
        let existing = makeExisting()
        StyleProfileAugment.merge(existing: existing, fresh: makeFresh(), reason: "追加")

        XCTAssertEqual(existing.sampleCharCount, 15_000)
        XCTAssertEqual(existing.examples.count, 1)
        XCTAssertEqual(existing.examples.first?.styled, "咖啡凉到第三口才想起来喝")
        XCTAssertEqual(existing.sourceNote, "《原样本》", "来源说明保留原值")
    }

    func testMergeRecordsCorrectionsForChangedFields() {
        let existing = makeExisting()
        StyleProfileAugment.merge(existing: existing, fresh: makeFresh(), reason: "追加样本《新样本》")

        let changedFields = existing.corrections.map(\.field)
        XCTAssertTrue(changedFields.contains("narrativeVoice.temperature"))
        XCTAssertTrue(changedFields.contains("fingerprintSummary"))
        let tempCorrection = existing.corrections.first { $0.field == "narrativeVoice.temperature" }
        XCTAssertEqual(tempCorrection?.before, "冷峻克制")
        XCTAssertEqual(tempCorrection?.after, "冷峻中带倦意")
        XCTAssertEqual(tempCorrection?.reason, "追加样本《新样本》")
        XCTAssertNil(existing.corrections.first { $0.field == "narrativeVoice.pov" }, "未变化字段不记日志")
    }

    func testCorrectionsCapped() {
        let existing = makeExisting()
        existing.corrections = (0..<StyleProfileAugment.maxCorrections).map {
            StyleCorrection(layer: "L1", field: "old\($0)", before: "a", after: "b", reason: "r")
        }
        StyleProfileAugment.merge(existing: existing, fresh: makeFresh(), reason: "追加")
        XCTAssertLessThanOrEqual(existing.corrections.count, StyleProfileAugment.maxCorrections)
        XCTAssertFalse(existing.corrections.contains { $0.field == "old0" }, "超出上限时淘汰最旧记录")
    }

    func testServiceAugmentRunReturnsUpdatedCopy() async throws {
        let analysisJSON = """
        {"narrative_voice":{"temperature":"冷峻中带倦意"},"sentence_syntax":{"shape":"短句主导"}}
        """
        let cardJSON = """
        {"name":"冷雨短句","tags":["冷峻"],"fingerprint_summary":"更新后的小结。",
         "must_rules":["短句为主"],"avoid_rules":["排比"],
         "examples":[{"plain":"他很累","styled":"咖啡凉了才想起","principle":"物件承载状态"}]}
        """
        let target = makeExisting()
        let client = MockLLMClient(responses: [analysisJSON, cardJSON])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))
        var profile: StyleProfile?

        for try await event in service.events(sourceText: String(repeating: "雨。", count: 600),
                                              sourceNote: "《新样本》",
                                              analyzeSystem: "分析", cardSystem: "汇总", fixSystem: "修正",
                                              augmentTarget: target) {
            if case .completed(let p) = event { profile = p }
        }

        let result = try XCTUnwrap(profile)
        XCTAssertEqual(result.id, target.id, "增量蒸馏产出与原档案同 id（upsert 即更新）")
        XCTAssertEqual(result.narrativeVoice.temperature, "冷峻中带倦意")
        XCTAssertEqual(result.narrativeVoice.pov, "第三人称贴身")
        XCTAssertFalse(result.corrections.isEmpty)
        XCTAssertEqual(result.sampleCharCount, target.sampleCharCount + 1_200)
        XCTAssertEqual(client.requestCount, 2)
        // 原对象不被就地修改（采纳与否由用户决定）
        XCTAssertEqual(target.narrativeVoice.temperature, "冷峻克制")
    }
}

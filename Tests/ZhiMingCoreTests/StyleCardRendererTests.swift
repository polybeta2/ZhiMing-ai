import XCTest
@testable import ZhiMingCore

final class StyleCardRendererTests: XCTestCase {
    private func makeProfile() -> StyleProfile {
        let p = StyleProfile(name: "冷峻白描")
        p.tags = ["冷峻", "白描"]
        p.fingerprintSummary = "短句为主，情绪藏在物件里。"
        p.mustRules = ["连续三句不超过15字", "每场景至多一处比喻"]
        p.avoidRules = ["禁止排比抒情"]
        p.narrativeVoice.temperature = "冷峻克制"
        p.narrativeVoice.pov = "第三人称贴身"
        p.sentenceSyntax.shape = "短句主导"
        p.diction.register = "口语书面混合"
        p.diction.bannedMoves = ["瞳孔地震", "心中涌起"]
        p.sceneRhythm.openings = "直接进入动作"
        p.dialogue.subtextLevel = "高潜台词"
        p.emotion.directness = "移置不直陈"
        p.antiAI.forbiddenPatterns = ["不是…而是…说明腔"]
        p.antiAI.revisionChecks = ["检查句长是否均一"]
        p.examples = [StyleExample(plain: "他很生气", styled: "他把杯子顿在桌上", principle: "情绪外化")]
        return p
    }

    func testWritingVariantContainsCoreSections() {
        let card = StyleCardRenderer.render(makeProfile(), variant: .writing)
        XCTAssertTrue(card.contains("【文风档案：冷峻白描】"))
        XCTAssertTrue(card.contains("以风格约束为准"), "必须声明 styleGuide 优先")
        XCTAssertTrue(card.contains("短句为主"))
        XCTAssertTrue(card.contains("必遵规则"))
        XCTAssertTrue(card.contains("连续三句不超过15字"))
        XCTAssertTrue(card.contains("绝对禁止"))
        XCTAssertTrue(card.contains("他把杯子顿在桌上"))
        XCTAssertTrue(card.contains("冷峻克制"), "分层要点应包含语气温度")
    }

    func testOutlineVariantOmitsSyntaxDetail() {
        let card = StyleCardRenderer.render(makeProfile(), variant: .outline)
        XCTAssertTrue(card.contains("第三人称贴身"))
        XCTAssertTrue(card.contains("直接进入动作"))
        XCTAssertFalse(card.contains("必遵规则"), "大纲 variant 不注入词汇级规则")
        XCTAssertFalse(card.contains("他把杯子顿在桌上"))
    }

    func testAntiAIVariantOnlyAntiSections() {
        let card = StyleCardRenderer.render(makeProfile(), variant: .antiAI)
        XCTAssertTrue(card.contains("禁止模式"))
        XCTAssertTrue(card.contains("检查句长是否均一"))
        XCTAssertTrue(card.contains("瞳孔地震"), "bannedMoves 应并入去AI味专项")
        XCTAssertFalse(card.contains("他把杯子顿在桌上"))
        XCTAssertFalse(card.contains("短句为主"))
    }

    func testBudgetRespected() {
        var p = makeProfile()
        p.mustRules = (0..<50).map { String(repeating: "长", count: 60) + "\($0)" }
        let card = StyleCardRenderer.render(p, variant: .writing)
        XCTAssertLessThanOrEqual(card.count, PromptLimits.styleProfileCap)
        XCTAssertFalse(card.isEmpty)
    }

    func testNovelCardResolution() {
        let p = makeProfile()
        let novel = Novel(title: "测试书")
        XCTAssertNil(novel.styleProfileCard(in: [p], variant: .writing))
        novel.activeStyleProfileID = p.id
        XCTAssertNotNil(novel.styleProfileCard(in: [p], variant: .writing))
        XCTAssertNil(novel.styleProfileCard(in: [], variant: .writing))
    }
}

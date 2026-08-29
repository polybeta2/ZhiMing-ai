import XCTest
@testable import ZhiMingCore

/// 三级上下文装配：必需层不裁剪 / 可选层预算贪心 / 伏笔提醒
final class ContextBuilderTests: XCTestCase {

    func testRequiredLayerSurvivesTinyBudget() {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100)

        // 必需层（细纲/场景卡/正文末尾）不受预算影响
        XCTAssertTrue(ctx.rendered.contains("【本章细纲】"))
        XCTAssertTrue(ctx.rendered.contains("夜探纸坊旧址"))
        XCTAssertTrue(ctx.rendered.contains("【场景卡】"))
        XCTAssertTrue(ctx.rendered.contains("印刷机是热的"))
        XCTAssertTrue(ctx.rendered.contains("【正文末尾】"))
        // 可选层（角色/世界观）被裁并上报
        XCTAssertTrue(ctx.truncatedSections.contains("角色状态"))
        XCTAssertTrue(ctx.truncatedSections.contains("世界观"))
    }

    func testHighPriorityLayerWithinBudget() {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)

        // 预算充足：前两章摘要 + 关键事实全量注入
        XCTAssertTrue(ctx.rendered.contains("【前文摘要（最近 2 章）】"))
        XCTAssertTrue(ctx.rendered.contains("署名亡者的信"))
        XCTAssertTrue(ctx.rendered.contains("【关键事实】"))
        XCTAssertTrue(ctx.rendered.contains("旧纸坊十年前烧毁"))
        XCTAssertTrue(ctx.rendered.contains("【角色当前状态】"))
        XCTAssertTrue(ctx.rendered.contains("沈探长"))
        XCTAssertTrue(ctx.rendered.contains("【世界观条目】"))
        XCTAssertTrue(ctx.truncatedSections.isEmpty)
    }

    /// 正文末尾 800 字兜底：长正文只保留尾部
    func testContentTailCappedAt800() {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)
        chapter.content = String(repeating: "潮水拍打着堤岸。", count: 501) + "了"   // 4009 字，断点错位

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)
        let tailSection = ctx.rendered.split(separator: "【正文末尾】").last ?? ""
        XCTAssertLessThanOrEqual(tailSection.count, ContextBuilder.tailLength + 10)
        // 501 次重复非 8 字对齐：suffix(800) 必从句中开始，头部文本不应出现
        XCTAssertFalse(tailSection.hasPrefix("\n潮水拍打着堤岸。潮水"))
    }

    func testStyleGuideCappedWithTruncationNotice() {
        let novel = Fixtures.makeNovel()
        novel.styleGuide = String(repeating: "短句。白描。克制。", count: 600)   // 5400 字
        let chapter = Fixtures.targetChapter(in: novel)

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)
        XCTAssertTrue(ctx.truncatedSections.contains { $0.contains("风格约束") && $0.contains("4000") })
        XCTAssertTrue(ctx.rendered.contains("【风格约束】\n……"))   // 留尾不留头
    }

    /// 伏笔提醒：open + 有计划回收 → 注入；resolved → 不注入
    func testForeshadowReminderInjected() {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)
        XCTAssertTrue(ctx.rendered.contains("【未回收伏笔提醒】"))
        XCTAssertTrue(ctx.rendered.contains("烧毁的印刷机"))
        XCTAssertTrue(ctx.rendered.contains("计划回收"))

        novel.foreshadowings[0].status = .resolved
        let ctx2 = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)
        XCTAssertFalse(ctx2.rendered.contains("【未回收伏笔提醒】"))
    }

    /// 埋设章距当前章不足阈值（8 章）且无计划回收 → 不提醒
    func testForeshadowBelowThresholdNotReminded() {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)
        novel.foreshadowings[0].plannedResolve = nil

        let ctx = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel, budgetChars: 100_000)
        XCTAssertFalse(ctx.rendered.contains("【未回收伏笔提醒】"))
    }
}

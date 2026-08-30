import XCTest
@testable import ZhiMingCore

/// 章间衔接锚点（P2.6）：写 X 章时注入 X-1 正文末尾与 X+1 细纲开头
final class NeighborSeamTests: XCTestCase {
    /// 三章书：第一章有长正文（结尾时刻明确），第二章为撰写目标（有正文供末章用例），第三章有细纲
    private func makeNovel() -> Novel {
        let novel = Novel(title: "雾港来信", synopsis: "一封来自死去之人的信")
        let v1 = Volume(name: "第一卷", sortOrder: 1)

        let c1 = Chapter(title: "第一章 死信", sortOrder: 1)
        c1.content = "开篇句。巷口的灯刚刚亮起。"
            + String(repeating: "中间的调查推进。", count: 200)
            + "沈屿捏着信纸的手停在半空，窗外的雨还没有停。"
        let c2 = Chapter(title: "第二章 旧档", sortOrder: 2)
        c2.detailedOutline = "沈屿前往旧纸坊查档，发现十年前的印刷批次记录被人抽走，纸坊看守欲言又止。"
        c2.content = String(repeating: "第二章正文。", count: 80)
        let c3 = Chapter(title: "第三章 潜入", sortOrder: 3)
        c3.detailedOutline = "夜里沈屿潜回纸坊，看见印刷机仍在运转，有人比他先到了一步。"

        v1.chapters = [c1, c2, c3]
        novel.volumes = [v1]
        v1.novel = novel
        c1.volume = v1
        c2.volume = v1
        c3.volume = v1
        return novel
    }

    func testMiddleChapterGetsBothAnchors() throws {
        let novel = makeNovel()
        let target = try XCTUnwrap(novel.volumes.first?.chapters[1])
        let context = ContextBuilder.buildContinueContext(chapter: target, novel: novel, budgetChars: 20_000)

        XCTAssertTrue(context.rendered.contains("【上一章正文末尾】"), "必须注入上一章实际正文结尾")
        XCTAssertTrue(context.rendered.contains("沈屿捏着信纸的手停在半空"), "必须是正文最后时刻而非开篇")
        XCTAssertFalse(context.rendered.contains("开篇句。"), "只取尾部，不搬运全章")
        XCTAssertTrue(context.rendered.contains("【下一章细纲（开头走向）】"), "必须注入下一章细纲开头")
        XCTAssertTrue(context.rendered.contains("沈屿潜回纸坊"), "下一章细纲内容可见")
    }

    func testFirstChapterOmitsPrevTail() throws {
        let novel = makeNovel()
        let first = try XCTUnwrap(novel.volumes.first?.chapters[0])
        let context = ContextBuilder.buildContinueContext(chapter: first, novel: novel, budgetChars: 20_000)
        XCTAssertFalse(context.rendered.contains("【上一章正文末尾】"), "首章无上一章")
        // 第二章有细纲 → 首章仍应有下一章落点
        XCTAssertTrue(context.rendered.contains("【下一章细纲（开头走向）】"))
    }

    func testLastChapterOmitsNextOutline() throws {
        let novel = makeNovel()
        let last = try XCTUnwrap(novel.volumes.first?.chapters[2])
        last.detailedOutline = "末章细纲。"
        let context = ContextBuilder.buildContinueContext(chapter: last, novel: novel, budgetChars: 20_000)
        XCTAssertFalse(context.rendered.contains("【下一章细纲（开头走向）】"), "末章无下一章")
        XCTAssertTrue(context.rendered.contains("【上一章正文末尾】"))
    }

    func testPrevWithoutContentOmitsTail() throws {
        let novel = makeNovel()
        guard let v1 = novel.volumes.first else { return XCTFail() }
        v1.chapters[0].content = ""   // 上一章还没写（跳章写作）
        let target = try XCTUnwrap(v1.chapters[1])
        let context = ContextBuilder.buildContinueContext(chapter: target, novel: novel, budgetChars: 20_000)
        XCTAssertFalse(context.rendered.contains("【上一章正文末尾】"), "上一章无正文时省略")
        XCTAssertTrue(context.rendered.contains("【下一章细纲（开头走向）】"))
    }

    func testNextWithoutOutlineOmitsHead() throws {
        let novel = makeNovel()
        guard let v1 = novel.volumes.first else { return XCTFail() }
        v1.chapters[2].detailedOutline = nil
        let target = try XCTUnwrap(v1.chapters[1])
        let context = ContextBuilder.buildContinueContext(chapter: target, novel: novel, budgetChars: 20_000)
        XCTAssertTrue(context.rendered.contains("【上一章正文末尾】"))
        XCTAssertFalse(context.rendered.contains("【下一章细纲（开头走向）】"), "下一章无细纲时省略")
    }
}

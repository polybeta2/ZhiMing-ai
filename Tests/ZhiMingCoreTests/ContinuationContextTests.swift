import XCTest
@testable import ZhiMingCore

final class ContinuationContextTests: XCTestCase {

    private func profile() -> SourceNovelProfile {
        let p = SourceNovelProfile(title: "斗罗大陆")
        p.continuationFromChapter = 120
        var tang = CanonCharacter(name: "唐三", role: "主角")
        tang.currentState = "96级封号斗罗"
        p.characters = [tang]
        p.openThreads = [CanonThread(title: "神秘令牌", detail: "黑袍人留下", plantedChapter: 95, participants: ["唐三"])]
        p.plotArc = "海神岛前夜"
        p.worldbuilding = [CanonWorldEntry(category: "力量体系", name: "武魂", content: "觉醒")]
        return p
    }

    func testRenderedContainsAllSections() {
        let text = ContinuationContext.rendered(profile: profile(), recentText: "第120章 尾声原文…", maxChars: 4000)
        XCTAssertTrue(text.contains("已分析原作前 120 章"))
        XCTAssertTrue(text.contains("从第 121 章起无缝续写"))
        XCTAssertTrue(text.contains("人物现状"))
        XCTAssertTrue(text.contains("现状：96级封号斗罗"))
        XCTAssertTrue(text.contains("未回收伏笔"))
        XCTAssertTrue(text.contains("埋于第 95 章"))
        XCTAssertTrue(text.contains("剧情弧与走向势能"))
        XCTAssertTrue(text.contains("海神岛前夜"))
        XCTAssertTrue(text.contains("世界设定"))
        XCTAssertTrue(text.contains("近期原文"))
        XCTAssertTrue(text.contains("第120章 尾声原文…"))
    }

    func testRenderedTruncatesToMaxChars() {
        var p = profile()
        var long = CanonCharacter(name: "唐三")
        long.currentState = String(repeating: "长", count: 500)
        p.characters = [long]
        let text = ContinuationContext.rendered(profile: p, recentText: nil, maxChars: 200)
        XCTAssertLessThanOrEqual(text.count, 200)
        XCTAssertTrue(text.contains("已截断"))
    }

    func testRenderedWithoutOptionalSectionsStillWorks() {
        let p = SourceNovelProfile(title: "空")
        p.continuationFromChapter = 5
        let text = ContinuationContext.rendered(profile: p, recentText: nil, maxChars: 1000)
        XCTAssertTrue(text.contains("已分析原作前 5 章"))
        XCTAssertFalse(text.contains("未回收伏笔"))
    }
}
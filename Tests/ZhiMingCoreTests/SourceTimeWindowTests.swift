import XCTest
@testable import ZhiMingCore

final class SourceTimeWindowTests: XCTestCase {

    private func makeProfile() -> SourceNovelProfile {
        let p = SourceNovelProfile(title: "斗罗", author: "唐家三少")
        var tang = CanonCharacter(name: "唐三", aliases: ["小三"], role: "主角")
        tang.arc = [CanonArc(stage: "史莱克期", change: "从稚嫩到担当")]
        var xw = CanonCharacter(name: "小舞", role: "主角")
        var db = CanonCharacter(name: "戴沐白", role: "配角")
        db.arc = [CanonArc(stage: "魂师大赛期", change: "独当一面")]
        p.characters = [tang, xw, db]
        p.timeline = [
            CanonEvent(phase: "史莱克期", summary: "入学考核", participants: ["唐三", "小舞"], importance: .major),
            CanonEvent(phase: "史莱克期", summary: "组建七怪", participants: ["唐三"], importance: .minor),
            CanonEvent(phase: "魂师大赛期", summary: "夺冠", participants: ["戴沐白"], importance: .major),
            CanonEvent(phase: nil, summary: "全书杂事", participants: [], importance: .minor),
        ]
        p.worldbuilding = [
            CanonWorldEntry(category: "力量体系", name: "武魂", content: "先天觉醒"),
            CanonWorldEntry(category: "地点", name: "史莱克学院", content: "怪物学园"),
        ]
        return p
    }

    func testWindowFiltersByPhase() {
        let tie = SourceTimeWindow.window(phase: "史莱克期", profile: makeProfile())
        XCTAssertEqual(tie.phase, "史莱克期")
        // 角色：arc 含史莱克期的唐三 + 事件参与的小舞（戴沐白是大赛期，不应出现）
        XCTAssertTrue(tie.characters.contains { $0.name == "唐三" })
        XCTAssertTrue(tie.characters.contains { $0.name == "小舞" })
        XCTAssertFalse(tie.characters.contains { $0.name == "戴沐白" })
        XCTAssertEqual(tie.events.count, 2)
        XCTAssertTrue(tie.events.allSatisfy { $0.phase == "史莱克期" })
    }

    func testWindowFallbackAllMajorWhenNil() {
        let whole = SourceTimeWindow.window(phase: nil, profile: makeProfile())
        XCTAssertNil(whole.phase)
        XCTAssertEqual(whole.characters.count, 3)
        XCTAssertEqual(whole.events.count, 2)   // 只含 major
        XCTAssertTrue(whole.events.allSatisfy { $0.importance == .major })
    }

    func testWindowUnknownPhaseFallsBack() {
        // 找不到的阶段 → 同 nil 回退（保证有内容可注入）
        let unknown = SourceTimeWindow.window(phase: "不存在的阶段", profile: makeProfile())
        XCTAssertEqual(unknown.characters.count, 3)
    }

    func testWindowRenderCaps() {
        let window = SourceTimeWindow.window(phase: nil, profile: makeProfile())
        let capped = window.rendered(maxChars: 120)
        XCTAssertLessThanOrEqual(capped.count, 121)
        XCTAssertTrue(capped.hasSuffix("……（已截断）") || capped.count <= 120)
        // 未封顶时包含关键内容
        let full = window.rendered(maxChars: 100_000)
        XCTAssertTrue(full.contains("唐三"))
        XCTAssertTrue(full.contains("史莱克期"))
    }
}
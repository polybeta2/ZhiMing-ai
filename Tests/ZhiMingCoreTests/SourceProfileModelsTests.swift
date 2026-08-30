import XCTest
@testable import ZhiMingCore

final class SourceProfileModelsTests: XCTestCase {
    func testProfileCodableRoundtrip() throws {
        var p = SourceNovelProfile(title: "斗罗", author: "唐家三少")
        p.meta = ScanMeta(totalChapters: 336, totalChars: 2_000_000, scanMode: .fast)
        p.characters.append(CanonCharacter(name: "唐三", aliases: ["小三"], role: "主角",
            oneLine: "双生武魂", personality: "坚韧", abilities: "蓝银草+昊天锤"))
        p.characters[0].relationships.append(CanonRelationship(target: "小舞", relation: "恋人"))
        p.characters[0].arc.append(CanonArc(stage: "史莱克期", change: "从稚嫩到担当"))
        p.timeline.append(CanonEvent(phase: "史莱克学院期", summary: "入学考核", participants: ["唐三"],
                                     importance: .major, consequence: "成为史莱克七怪"))
        p.worldbuilding.append(CanonWorldEntry(category: "力量体系", name: "武魂", content: "先天觉醒"))
        p.scanState = ScanState(stage: .done, totalChunks: 10, doneChunks: 10, tokensIn: 1000, tokensOut: 100)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(SourceNovelProfile.self, from: data)
        XCTAssertEqual(decoded.title, "斗罗")
        XCTAssertEqual(decoded.characters.count, 1)
        XCTAssertEqual(decoded.characters[0].aliases, ["小三"])
        XCTAssertEqual(decoded.timeline[0].importance, .major)
        XCTAssertEqual(decoded.scanState.stage, .done)
    }

    func testDecodesEmptyJSONDefaults() throws {
        // 旧档/空容器：缺字段不抛 keyNotFound（与 styleProfiles 同容错法）
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","title":"X"}"#
        let p = try JSONDecoder().decode(SourceNovelProfile.self, from: Data(json.utf8))
        XCTAssertEqual(p.characters.count, 0)
        XCTAssertEqual(p.timeline.count, 0)
        XCTAssertFalse(p.scanState.isComplete)
    }

    func testImportanceRanking() {
        XCTAssertTrue(Importance.major.majorRank > Importance.minor.majorRank)
    }
}

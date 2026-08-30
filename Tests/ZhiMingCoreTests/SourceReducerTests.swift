import XCTest
@testable import ZhiMingCore

final class SourceReducerTests: XCTestCase {

    func testBatchPromptCountAndReturns() {
        let micro = SourceMicroSummarizer.MicroSummary()
        let prompt = SourceReducer.batchPrompt(micros: [micro, micro], batchChars: 12000)
        XCTAssertTrue(prompt.contains("2 段微摘要"))
        XCTAssertTrue(prompt.contains("12000"))
    }

    func testFinalPromptAssembles() {
        let stage = "史莱克期：唐三入学。"
        let prompt = SourceReducer.finalPrompt(stageSummaries: [stage],
                                               characters: [CanonCharacter(name: "唐三")])
        let joined = prompt.map(\.content).joined()
        XCTAssertTrue(joined.contains("史莱克期"))
        XCTAssertTrue(joined.contains("唐三"))
        XCTAssertTrue(prompt.first?.role == .system)
        XCTAssertEqual(prompt.count, 2)
    }

    func testParseFinalProfile() throws {
        let json = """
        {"characters":[{"name":"唐三","role":"主角","oneLine":"双生武魂","arc":[{"stage":"史莱克期","change":"成熟"}]}],
         "timeline":[{"phase":"史莱克期","summary":"入学","participants":["唐三"],"importance":"major","consequence":"入七怪"}],
         "worldbuilding":[{"category":"力量体系","name":"武魂","content":"觉醒"}]}
        """
        let profile = try SourceReducer.parseFinal(json, fallbackTitle: "斗罗")
        XCTAssertEqual(profile.title, "斗罗")
        XCTAssertEqual(profile.characters.count, 1)
        XCTAssertEqual(profile.characters[0].arc.count, 1)
        XCTAssertEqual(profile.timeline[0].importance, .major)
        XCTAssertEqual(profile.worldbuilding.count, 1)
    }

    func testParseFinalToleratesMissing() throws {
        let json = #"{"characters":[],"timeline":[],"worldbuilding":[]}"#
        let p = try SourceReducer.parseFinal(json, fallbackTitle: "X")
        XCTAssertEqual(p.characters.count, 0)
        XCTAssertEqual(p.timeline.count, 0)
        XCTAssertEqual(p.worldbuilding.count, 0)
    }

    func testParseFinalGarbageThrows() {
        XCTAssertThrowsError(try SourceReducer.parseFinal("不是JSON", fallbackTitle: "X"))
    }
}
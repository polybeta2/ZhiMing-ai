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

    func testContinuationPromptAssembles() {
        let msgs = SourceReducer.continuationPrompt(stageSummaries: ["史莱克期：唐三入学。未回收伏笔：神秘令牌。"],
                                                    upToChapter: 120)
        let joined = msgs.map(\.content).joined()
        XCTAssertTrue(joined.contains("120"))
        XCTAssertTrue(joined.contains("open_threads"))
        XCTAssertTrue(joined.contains("current_state"))
        XCTAssertTrue(joined.contains("plot_arc"))
        XCTAssertEqual(msgs.first?.role, .system)
    }

    func testParseContinuationFull() throws {
        let json = """
        {"title_suggestion":"斗罗大陆",
         "characters":[{"name":"唐三","current_state":"96级封号斗罗，心理：为救小舞不惜一切"}],
         "timeline":[{"summary":"入学","participants":["唐三"],"importance":"major"}],
         "worldbuilding":[{"category":"力量体系","name":"武魂","content":"觉醒"}],
         "open_threads":[{"title":"神秘令牌","detail":"黑袍人留下","planted_chapter":95,"participants":["唐三"]}],
         "plot_arc":"主线冲突进入海神岛前夜，下一阶段走向：海神考核。"}
        """
        let profile = try SourceReducer.parseContinuation(json, fallbackTitle: "斗罗", upToChapter: 120)
        XCTAssertEqual(profile.continuationFromChapter, 120)
        XCTAssertEqual(profile.characters[0].currentState, "96级封号斗罗，心理：为救小舞不惜一切")
        XCTAssertEqual(profile.openThreads.count, 1)
        XCTAssertEqual(profile.openThreads[0].plantedChapter, 95)
        XCTAssertEqual(profile.plotArc, "主线冲突进入海神岛前夜，下一阶段走向：海神考核。")
    }

    func testParseContinuationToleratesMissingOptional() throws {
        let json = #"{"characters":[],"timeline":[],"worldbuilding":[]}"#
        let profile = try SourceReducer.parseContinuation(json, fallbackTitle: "X", upToChapter: 10)
        XCTAssertEqual(profile.continuationFromChapter, 10)
        XCTAssertTrue(profile.openThreads.isEmpty)
        XCTAssertNil(profile.plotArc)
    }
}
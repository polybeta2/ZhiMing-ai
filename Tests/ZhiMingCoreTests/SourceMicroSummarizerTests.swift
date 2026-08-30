import XCTest
@testable import ZhiMingCore

final class SourceMicroSummarizerTests: XCTestCase {

    func testPromptAssembly() {
        let prompt = SourceMicroSummarizer.prompt(forChunk: "第2章 唐三七绝", maxOutChars: 350)
        XCTAssertTrue(prompt.contains("只记本段新增/变化"))
        XCTAssertTrue(prompt.contains("第2章"))
        XCTAssertTrue(prompt.contains("350"))
    }

    func testMessagesShape() {
        let msgs = SourceMicroSummarizer.messages(chunk: "正文内容", chapterMarker: "第2章 试炼")
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0].role, .system)
        XCTAssertEqual(msgs[1].role, .user)
        XCTAssertTrue(msgs[1].content.contains("第2章 试炼"))
        XCTAssertTrue(msgs[1].content.contains("正文内容"))
    }

    func testParseNormal() throws {
        let json = #"{"characters":[{"name":"唐三","traits":"使用暗器","state_change":"突破魂尊"}],"events":[{"summary":"击败人面魔蛛","participants":["唐三"]}],"worldbuilding":[{"name":"暗器","content":"唐门暗器百步穿杨"}]}"#
        let micro = try SourceMicroSummarizer.parse(json)
        XCTAssertEqual(micro.characters.count, 1)
        XCTAssertEqual(micro.characters[0].name, "唐三")
        XCTAssertEqual(micro.characters[0].state_change, "突破魂尊")
        XCTAssertEqual(micro.events.count, 1)
        XCTAssertEqual(micro.worldbuilding[0].name, "暗器")
    }

    func testParseFencedJSONTolerated() throws {
        let raw = "```json\n{\"characters\":[],\"events\":[{\"summary\":\"x\",\"participants\":[]}],\"worldbuilding\":[]}\n```"
        let micro = try SourceMicroSummarizer.parse(raw)   // 宽容剥围栏
        XCTAssertEqual(micro.events.count, 1)
    }

    func testParseMissingFieldsDefaultEmpty() throws {
        let micro = try SourceMicroSummarizer.parse(#"{ }"#)
        XCTAssertEqual(micro.characters.count, 0)
        XCTAssertEqual(micro.events.count, 0)
        XCTAssertEqual(micro.worldbuilding.count, 0)
    }

    func testParseFailsOnGarbage() {
        XCTAssertThrowsError(try SourceMicroSummarizer.parse("不是JSON"))
    }

    func testParseForeshadowing() throws {
        let json = """
        {"characters":[],"events":[],"worldbuilding":[],
         "foreshadowing":[{"summary":"神秘黑袍人留下令牌","planted":true},{"summary":"山贼头目的宝藏地图悬念解除","planted":false}]}
        """
        let micro = try SourceMicroSummarizer.parse(json)
        XCTAssertEqual(micro.foreshadowing.count, 2)
        XCTAssertEqual(micro.foreshadowing[0].summary, "神秘黑袍人留下令牌")
        XCTAssertTrue(micro.foreshadowing[0].planted)
        XCTAssertFalse(micro.foreshadowing[1].planted)
    }

    func testParseLegacyMicroSummaryWithoutForeshadowing() throws {
        let json = #"{"characters":[],"events":[],"worldbuilding":[]}"#
        let micro = try SourceMicroSummarizer.parse(json)
        XCTAssertTrue(micro.foreshadowing.isEmpty)
    }

    func testSystemPromptMentionsForeshadowing() {
        let msgs = SourceMicroSummarizer.messages(chunk: "正文", chapterMarker: "第1章")
        XCTAssertTrue(msgs[0].content.contains("foreshadowing"))
    }
}

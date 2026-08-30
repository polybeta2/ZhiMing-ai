import XCTest
@testable import ZhiMingCore

final class SourceBatchHelperTests: XCTestCase {

    private func body(_ n: Int) -> String { String(repeating: "内容\(n)号", count: 20) }

    func testPromptAssemblesRangeAndBlocks() {
        let chapters = [(1, "第1章 开端", body(1)), (2, "第2章 发展", body(2))]  // 1-based 章号
        let prompt = SourceBatchHelper.prompt(title: "斗罗", chapters: chapters)
        XCTAssertTrue(prompt.contains("第 1-2 章"))
        XCTAssertTrue(prompt.contains("共 2 章"))
        XCTAssertTrue(prompt.contains("【第1章 开端】"))
        XCTAssertTrue(prompt.contains("【第2章 发展】"))
        XCTAssertTrue(prompt.contains("{\"chapter\""))
    }

    func testParseBatchOutputNormal() throws {
        let raw = #"""
        {"chapter": 1, "characters": [{"name": "唐三", "traits": "冷静"}], "events": [{"summary": "入学", "participants": ["唐三"]}], "worldbuilding": []}
        {"chapter": 2, "characters": [], "events": [], "worldbuilding": [{"name": "武魂", "content": "觉醒"}]}
        """#
        let parsed = try SourceBatchHelper.parseBatchOutput(raw)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0]?.characters.first?.name, "唐三")
        XCTAssertEqual(parsed[1]?.worldbuilding.first?.name, "武魂")
    }

    func testParseBatchOutputToleratesFenceAndNoise() throws {
        let raw = """
        以下是分析结果：
        ```json
        {"chapter": 5, "characters": [{"name": "小舞", "state_change": "突破"}], "events": [], "worldbuilding": []}
        ```
        全部完成。
        """
        let parsed = try SourceBatchHelper.parseBatchOutput(raw)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[4]?.characters.first?.name, "小舞")
        XCTAssertEqual(parsed[4]?.characters.first?.state_change, "突破")
    }

    func testParseBatchOutputGarbageThrows() {
        XCTAssertThrowsError(try SourceBatchHelper.parseBatchOutput("没有 JSON"))
    }

    func testExtractJSONObjectsSkipsExplainBraces() {
        let text = "说明 {不是目标} 然后 {" + #"{"chapter": 3, "characters": []}"# + "} 结尾"
        let jsons = SourceBatchHelper.extractJSONObjects(from: text, matchingKey: "chapter")
        XCTAssertEqual(jsons.count, 1)
        XCTAssertTrue(jsons[0].contains("chapter"))
    }
}
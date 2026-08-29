import XCTest
@testable import ZhiMingCore

/// JSON 提取器：括号配平 / 围栏 / 尾逗号清理
final class LLMJSONParserTests: XCTestCase {

    func testPlainObjectWithSurroundingProse() {
        let text = "好的，以下是蓝图：{\"a\": 1} 希望有帮助"
        XCTAssertEqual(LLMJSONParser.extractJSONObject(from: text), #"{"a": 1}"#)
    }

    /// 字符串内的花括号不得干扰配平（此前会把 [{...},{...}] 截成非法片段）
    func testStringAwareBraceBalancing() {
        let text = #"结果：[{"a": "含 } 花括号"}, {"b": 2}] 结束"#
        XCTAssertEqual(LLMJSONParser.extractJSONObject(from: text),
                       #"[{"a": "含 } 花括号"}, {"b": 2}]"#)
    }

    /// 转义引号内的字符不计入配平
    func testEscapedQuoteBalancing() {
        let text = #"{"say": "他说 \" } 好看\""}"#
        XCTAssertEqual(LLMJSONParser.extractJSONObject(from: text), text)
    }

    func testUnclosedReturnsNil() {
        XCTAssertNil(LLMJSONParser.extractJSONObject(from: "{\"a\": [1, 2"))
    }

    func testNoJSONReturnsNil() {
        XCTAssertNil(LLMJSONParser.extractJSONObject(from: "完全没有任何结构化内容"))
    }

    /// 首个完整 JSON 值：对象与数组谁先出现取谁
    func testFirstCompleteValueWins() {
        let text = #"{"x": 1} 之后的 {"y": 2}"#
        XCTAssertEqual(LLMJSONParser.extractJSONObject(from: text), #"{"x": 1}"#)
    }

    func testDecodeFromFencedJSON() throws {
        let text = """
        ```json
        {"summary": "本章摘要", "key_facts": ["事实一"]}
        ```
        """
        let result = try XCTUnwrap(LLMJSONParser.decode(LLMJSONParser.SummaryResult.self, fromJSONObjectIn: text))
        XCTAssertEqual(result.summary, "本章摘要")
        XCTAssertEqual(result.key_facts, ["事实一"])
    }

    /// 尾逗号清理：部分网关模型会输出 `"a",]` / `"a",}`
    func testLenientRetryStripsTrailingCommas() throws {
        let text = """
        ```json
        {"summary": "摘要", "key_facts": ["一", "二",],}
        ```
        """
        let result = try XCTUnwrap(LLMJSONParser.decode(LLMJSONParser.SummaryResult.self, fromJSONObjectIn: text))
        XCTAssertEqual(result.key_facts, ["一", "二"])
    }

    func testDecodeGarbageReturnsNil() {
        XCTAssertNil(LLMJSONParser.decode(LLMJSONParser.SummaryResult.self, fromJSONObjectIn: "前面全是散文，没有 JSON"))
    }
}

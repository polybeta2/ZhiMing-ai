import XCTest
@testable import ZhiMingCore

/// 章节划分、序号裁决与自适应抽样（整本网文 5MB 级输入的预处理）
final class StyleChapterSamplerTests: XCTestCase {
    private func chapter(_ marker: String, body: String = "正文内容。") -> String {
        marker + "\n" + body + "\n"
    }

    // MARK: 基本划分

    func testSplitByChineseChapterMarkers() {
        let text = chapter("第一章 夜探") + chapter("第二章 旧档") + chapter("第三章 潜入")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].marker, "第一章 夜探")
        XCTAssertEqual(chapters[0].number, 1)
        XCTAssertEqual(chapters[2].number, 3)
    }

    func testSplitByChineseNumerals() {
        let text = chapter("第一百二十三章 潮落") + chapter("第一百二十四章 归途")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[1].number, 124)
    }

    func testSplitByPureNumberLines() {
        let text = chapter("001") + chapter("002") + chapter("003")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters.map(\.number), [1, 2, 3])
    }

    func testInlineMentionDoesNotSplit() {
        let text = "第一章 开端\n他说起第3章的内容，还有第178页的批注。\n第二章 进展\n"
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 2, "行中提及不构成章节标记")
    }

    func testNoMarkersReturnsEmpty() {
        XCTAssertTrue(StyleChapterSampler.split("这是一段没有章节标记的短文。\n再来一段。").isEmpty)
    }

    // MARK: 序号裁决

    func testSpikeAndReturnMarkersAreDropped() {
        // 用户案例：028, 029, 178, 191, 030 → 178/191 为假标记，其正文按文档序并入下一存活章 030
        let text = chapter("028", body: "甲。") + chapter("029", body: "乙。")
            + chapter("178", body: "页码假章。") + chapter("191", body: "又一个假章。")
            + chapter("030", body: "丙。")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.map(\.number), [28, 29, 30])
        XCTAssertTrue(chapters[2].body.contains("页码假章"), "被裁段的正文并入下一个存活章（保持文档顺序）")
        XCTAssertTrue(chapters[2].body.contains("丙。"))
    }

    func testMonotonicJumpIsKept() {
        // 30 → 35（缺卷跳号，永不回落）是合法章节
        let text = chapter("第30章") + chapter("第35章")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.map(\.number), [30, 35])
    }

    func testDuplicateMarkerKeepsFirst() {
        let text = chapter("第五章") + "正文甲。\n" + "第五章" + "\n重复段。\n" + chapter("第六章")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].number, 5)
        XCTAssertTrue(chapters[1].body.contains("重复段"), "重复标记降级为正文并入下一个存活章")
    }

    func testTooFewNumbersSkipsAdjudication() {
        // 只有两个数字标记：不做裁决（样本太少，宁可信其真）
        let text = chapter("1") + chapter("999")
        let chapters = StyleChapterSampler.split(text)
        XCTAssertEqual(chapters.count, 2)
    }

    // MARK: 抽样选择

    private let deterministic: (Range<Int>) -> Int = { $0.lowerBound }

    func testSelectInitialSmallTakesAll() {
        XCTAssertEqual(StyleChapterSampler.selectInitial(total: 5, pickRandom: deterministic), [0, 1, 2, 3, 4])
    }

    func testSelectInitialLargeTakesEndsAndMiddle() {
        let picked = StyleChapterSampler.selectInitial(total: 100, pickRandom: deterministic)
        XCTAssertEqual(picked.count, 6)
        XCTAssertEqual(picked.prefix(2), [0, 1])
        XCTAssertEqual(picked.suffix(2), [98, 99])
        // deterministic 取区间下界 → 中段两章均在四分之一窗内且不与首尾重复
        XCTAssertTrue(picked[2] >= 25 && picked[2] < 75)
    }

    func testExpandAddsUnusedUpToCap() {
        var picked = StyleChapterSampler.selectInitial(total: 100, pickRandom: deterministic)
        picked = StyleChapterSampler.expand(picked, total: 100, pickRandom: deterministic)
        XCTAssertEqual(picked.count, 8)
        picked = StyleChapterSampler.expand(picked, total: 100, pickRandom: deterministic)
        XCTAssertEqual(picked.count, 10, "至多 10 章")
        picked = StyleChapterSampler.expand(picked, total: 100, pickRandom: deterministic)
        XCTAssertEqual(picked.count, 10, "已达上限不再扩张")
        XCTAssertEqual(picked, Array(Set(picked)).sorted(), "无重复")
    }
}

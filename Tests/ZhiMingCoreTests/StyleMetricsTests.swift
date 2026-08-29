import XCTest
@testable import ZhiMingCore

final class StyleMetricsTests: XCTestCase {
    func testSampleSegmentsShortTextPassthrough() {
        let text = String(repeating: "短文本。", count: 100)   // 400 字 < 24000
        let samples = StyleMetrics.sampleSegments(in: text, maxChars: 24_000)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].label, "全文")
        XCTAssertEqual(samples[0].text, text)
    }

    func testSampleSegmentsLongTextSplitsThree() {
        let text = String(repeating: "字", count: 30_000)
        let samples = StyleMetrics.sampleSegments(in: text, maxChars: 24_000)
        XCTAssertEqual(samples.map(\.label), ["开头", "中段", "结尾"])
        XCTAssertTrue(samples.allSatisfy { $0.text.count <= 24_000 / 3 })
    }

    func testSampleSegmentsEmptyText() {
        XCTAssertTrue(StyleMetrics.sampleSegments(in: "   \n ", maxChars: 100).isEmpty)
    }

    func testComputeSentenceStats() {
        let text = "短句。这是一个中等长度的句子吗？是的，它确实是。这一句相当长，因为它包含了很多很多很多的字，足够跨过二十五字的分界线了！"
        let metrics = StyleMetrics.compute(text)
        XCTAssertEqual(metrics.sentenceCount, 4)
        XCTAssertEqual(metrics.medianSentenceLength, 9.5)   // 排序后 [2,7,12,35] → (7+12)/2
        XCTAssertEqual(metrics.shortSentenceRatio, 0.5)     // 「短句」2字 与「是的，它确实是」7字
        XCTAssertEqual(metrics.longSentenceRatio, 0.25)     // 末句 35 字
        XCTAssertGreaterThan(metrics.questionPer1k, 0)
        XCTAssertGreaterThan(metrics.exclamationPer1k, 0)
    }

    func testComputeDialogueRatio() {
        let metrics = StyleMetrics.compute("「你来了。」他说。\n plain line without quote \n" + String(repeating: "x", count: 60))
        XCTAssertGreaterThan(metrics.dialogueLineRatio, 0)
        XCTAssertLessThan(metrics.dialogueLineRatio, 1)
    }

    func testNgramViolationDetectsEightCharOverlap() {
        let original = "他缓缓推开那扇沉重的木门走进房间"
        let copied = "夜里他缓缓推开那扇沉重的木门走进房间，四下无人。"   // 含 8+ 字连续重合
        let clean = "夜色沉沉，门轴发出一声轻响，他侧身而入。"
        XCTAssertTrue(StyleMetrics.hasViolation(copied, against: original))
        XCTAssertFalse(StyleMetrics.hasViolation(clean, against: original))
        let violations = StyleMetrics.ngramViolations(in: [copied, clean], against: original)
        XCTAssertEqual(violations.count, 1)
    }

    func testNgramIgnoresPunctuationAndCase() {
        let original = "The Door Opened Slowly"
        let candidate = "the door opened slowly"
        XCTAssertTrue(StyleMetrics.hasViolation(candidate, against: original, n: 4))
    }
}

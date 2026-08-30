import XCTest
@testable import ZhiMingCore

final class SourceScanChunkerTests: XCTestCase {
    private func fixture() -> String {
        var s = ""
        for i in 1...5 {
            s += "第\(i)章 章名\(i)\n" + String(repeating: "内容\(i)号", count: 400) + "\n"
        }
        return s
    }

    func testFastWindowSamplesHeadAndTail() {
        let chunks = SourceScanChunker.chunks(from: fixture(), mode: .fast, headChars: 2500, tailChars: 1500)
        // 5 章 × 2 窗，每章正文 1200 字（内容i号×400→400×3字=1200），各窗 1200 ≤ 2500 → 每章 1 块
        XCTAssertEqual(chunks.count, 5)
    }

    func testFullModeBlocksWholeChapters() {
        // 每章 1200 字 < 10000 → 整章 1 块
        let chunks = SourceScanChunker.chunks(from: fixture(), mode: .full, chunkChars: 10000)
        XCTAssertEqual(chunks.count, 5)
        XCTAssertEqual(chunks.map(\.chapterIndex), [0, 1, 2, 3, 4])
    }

    func testFullModeSplitsLongChapter() {
        let body = "长" + String(repeating: "A", count: 25000)
        let s = "第1章 超长\n" + body
        let chunks = SourceScanChunker.chunks(from: s, mode: .full, chunkChars: 10000)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        let idxs = chunks.map(\.chunkIndex)
        XCTAssertEqual(idxs, idxs.sorted())
    }

    func testFastModeEmitsTwoWindowsPerLongChapter() {
        // 单章超长（> head+tail）→ 快扫应出 2 块（头窗 + 尾窗）
        let body = String(repeating: "乙", count: 10000)
        let s = "第1章 长章\n" + body
        let chunks = SourceScanChunker.chunks(from: s, mode: .fast, headChars: 2500, tailChars: 1500)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].text.count, 2500)
        XCTAssertEqual(chunks[1].text.count, 1500)
    }

    func testNoChapterMarkersFallbackToWindows() {
        let s = String(repeating: "无章正文", count: 2000)   // 无 "第X章" 标记
        let chunks = SourceScanChunker.chunks(from: s, mode: .full, chunkChars: 10000)
        XCTAssertGreaterThanOrEqual(chunks.count, 1)
        // 首/中/尾三窗兜底应被尊重：正文足够长时至少 3 块
        let s2 = String(repeating: "无章长文", count: 40000)
        let chunks2 = SourceScanChunker.chunks(from: s2, mode: .fast, headChars: 2500, tailChars: 1500)
        XCTAssertGreaterThanOrEqual(chunks2.count, 3)
    }
}

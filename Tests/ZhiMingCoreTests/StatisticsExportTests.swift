import XCTest
@testable import ZhiMingCore

/// 字数统计与导出
final class StatisticsExportTests: XCTestCase {

    private func makeThreeChapterNovel() -> Novel {
        let novel = Novel(title: "统计样例", synopsis: "")
        let v = Volume(name: "第一卷", sortOrder: 1)
        let c1 = Chapter(title: "甲", sortOrder: 1)
        c1.content = String(repeating: "字", count: 1500)
        let c2 = Chapter(title: "乙", sortOrder: 2)
        c2.content = String(repeating: "字", count: 500)
        let c3 = Chapter(title: "丙", sortOrder: 3)
        c3.content = ""
        v.chapters = [c1, c2, c3]
        novel.volumes = [v]
        v.novel = novel
        c1.volume = v; c2.volume = v; c3.volume = v
        return novel
    }

    func testCalculateBuckets() {
        let stats = StatisticsService.calculate(for: makeThreeChapterNovel())
        XCTAssertEqual(stats.totalWordCount, 2000)
        XCTAssertEqual(stats.completedChapters, 1)
        XCTAssertEqual(stats.draftChapters, 1)
        XCTAssertEqual(stats.emptyChapters, 1)
        XCTAssertEqual(stats.averageChapterWords, 666)
        XCTAssertEqual(stats.chapterWordCounts.map(\.title), ["甲", "乙", "丙"])
    }

    func testCompletedThresholdUnchanged() {
        XCTAssertEqual(StatisticsService.completedThreshold, 1000)
    }

    func testExportFullNovelTxtContainsContent() {
        let novel = Fixtures.makeNovel()
        let out = ExportService.export(novel: novel, scope: .fullNovel, format: .txt)
        XCTAssertTrue(out.contains("雾港来信"))
        XCTAssertTrue(out.contains("第一章 死信"))
        XCTAssertTrue(out.contains("码头晨雾未散"))
        XCTAssertTrue(out.contains("第三章 潜入"))
    }

    func testExportSingleVolume() {
        let novel = Fixtures.makeNovel()
        let volumeID = novel.sortedVolumes[0].id
        let out = ExportService.export(novel: novel, scope: .singleVolume(volumeID), format: .txt)
        XCTAssertTrue(out.contains("第一章 死信"))
        XCTAssertFalse(out.contains("第三章 潜入"))
    }

    func testExportOutlineOnlyContainsVolumeOutline() {
        let novel = Fixtures.makeNovel()
        let out = ExportService.export(novel: novel, scope: .outlineOnly, format: .markdown)
        XCTAssertTrue(out.contains("雾起"))
        XCTAssertTrue(out.contains("连环信件案的开端"))
    }

    func testFileNameShapes() {
        let novel = Fixtures.makeNovel()
        XCTAssertEqual(ExportService.fileName(novel: novel, scope: .fullNovel, format: .txt),
                       "《雾港来信》-全书.txt")
        XCTAssertEqual(ExportService.fileName(novel: novel, scope: .outlineOnly, format: .markdown),
                       "《雾港来信》-大纲.md")
    }

    func testWriteTemporaryFileRoundtrip() throws {
        let url = try XCTUnwrap(ExportService.writeTemporaryFile(content: "导出内容", fileName: "zm-test-\(UUID()).txt"))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "导出内容")
    }
}

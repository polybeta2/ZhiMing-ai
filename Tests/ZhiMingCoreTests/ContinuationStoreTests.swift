import XCTest
@testable import ZhiMingCore

final class ContinuationStoreTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("continuation-tests-\(UUID().uuidString)", isDirectory: true)
        ContinuationStore.overrideDirectory = dir
    }

    override func tearDown() {
        ContinuationStore.overrideDirectory = nil
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func testSaveLoadDeleteRoundTrip() {
        let id = UUID()
        XCTAssertNil(ContinuationStore.load(profileID: id))
        XCTAssertTrue(ContinuationStore.save(text: "第1章 正文", profileID: id))
        XCTAssertEqual(ContinuationStore.load(profileID: id), "第1章 正文")
        ContinuationStore.delete(profileID: id)
        XCTAssertNil(ContinuationStore.load(profileID: id))
    }

    func testLoadTailShortTextReturnsWhole() {
        let id = UUID()
        ContinuationStore.save(text: "短文本", profileID: id)
        XCTAssertEqual(ContinuationStore.loadTail(profileID: id, maxChars: 100), "短文本")
    }

    func testLoadTailAlignsToChapterMarker() {
        let id = UUID()
        let chapter = String(repeating: "字", count: 200)
        let text = "第9章 \(chapter)\n第10章 \(chapter)\n第11章 \(chapter)"
        ContinuationStore.save(text: text, profileID: id)
        let tail = ContinuationStore.loadTail(profileID: id, maxChars: 300)!
        XCTAssertTrue(tail.hasPrefix("……（前文略）\n第"))
        XCTAssertFalse(tail.contains("第9章"))   // 尾窗应对齐到后面的章节边界
        XCTAssertTrue(tail.contains("第11章"))
    }
}
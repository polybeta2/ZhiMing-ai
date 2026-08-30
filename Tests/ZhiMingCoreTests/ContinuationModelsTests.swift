import XCTest
@testable import ZhiMingCore

final class ContinuationModelsTests: XCTestCase {

    func testProfileDecodesLegacyJSONWithDefaults() throws {
        // 旧档案 JSON（无任何续写字段）必须能解码，且续写字段取默认值
        let legacy = #"{"id":"00000000-0000-0000-0000-000000000001","title":"斗罗"}"#
        let data = legacy.data(using: .utf8)!
        let profile = try JSONDecoder().decode(SourceNovelProfile.self, from: data)
        XCTAssertNil(profile.continuationFromChapter)
        XCTAssertTrue(profile.openThreads.isEmpty)
        XCTAssertNil(profile.plotArc)
        XCTAssertFalse(profile.hasSourceText)
    }

    func testProfileRoundTripContinuationFields() throws {
        let profile = SourceNovelProfile(title: "续写书")
        profile.continuationFromChapter = 120
        profile.openThreads = [CanonThread(title: "唐三的杀神领域伏笔", detail: "杀戮之都埋下",
                                            plantedChapter: 95, participants: ["唐三"])]
        profile.plotArc = "主线进入海神岛前夜"
        profile.hasSourceText = true
        let data = try JSONEncoder().encode(profile)
        let back = try JSONDecoder().decode(SourceNovelProfile.self, from: data)
        XCTAssertEqual(back.continuationFromChapter, 120)
        XCTAssertEqual(back.openThreads.first?.title, "唐三的杀神领域伏笔")
        XCTAssertEqual(back.openThreads.first?.plantedChapter, 95)
        XCTAssertEqual(back.plotArc, "主线进入海神岛前夜")
        XCTAssertTrue(back.hasSourceText)
    }

    func testCanonThreadDecodesMissingFields() throws {
        let json = #"{"title":"伏笔"}"#
        let thread = try JSONDecoder().decode(CanonThread.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(thread.title, "伏笔")
        XCTAssertEqual(thread.detail, "")
        XCTAssertNil(thread.plantedChapter)
        XCTAssertTrue(thread.participants.isEmpty)
    }

    func testCanonCharacterCurrentStateDecode() throws {
        let json = #"{"name":"唐三","current_state":"96级封号斗罗，持有海神三叉戟"}"#
        let c = try JSONDecoder().decode(CanonCharacter.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(c.currentState, "96级封号斗罗，持有海神三叉戟")
        // 旧数据无该字段仍可解码
        let legacy = #"{"name":"小舞"}"#
        let c2 = try JSONDecoder().decode(CanonCharacter.self, from: legacy.data(using: .utf8)!)
        XCTAssertNil(c2.currentState)
    }
}
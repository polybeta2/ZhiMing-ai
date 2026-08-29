import XCTest
@testable import ZhiMingCore

/// Linux XCTest 不支持 @MainActor 测试类；与 PromptTemplatesTests 同模式，
/// 经 MainActor.assumeIsolated 访问 @MainActor 的 AppStore。
final class StyleStoreTests: XCTestCase {
    override func setUp() {
        MainActor.assumeIsolated {
            AppStore.directoryOverride = FileManager.default.temporaryDirectory
                .appendingPathComponent("zm-style-tests-\(UUID().uuidString)", isDirectory: true)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            AppStore.directoryOverride = nil
        }
    }

    func testNovelBindingDecodesFromOldJSON() throws {
        // 旧版 Novel JSON（无 activeStyleProfileID）必须兼容
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","title":"旧书","synopsis":"","createdAt":0,"updatedAt":0,
         "volumes":[],"characters":[],"worldEntries":[],"chatThreads":[],"foreshadowings":[],"enabledTagIDs":[],"r18Enabled":false,"lastTotalWordCount":0}
        """
        let novel = try JSONDecoder().decode(Novel.self, from: Data(json.utf8))
        XCTAssertNil(novel.activeStyleProfileID)
    }

    func testStyleProfilesRoundtripThroughLibrary() throws {
        try MainActor.assumeIsolated {
            let store = AppStore()
            let profile = StyleProfile(name: "冷峻白描", sourceNote: "《示例》前三章", sampleCharCount: 12_345)
            profile.mustRules = ["短句为主"]
            store.styleProfiles.append(profile)
            store.save()

            let reloaded = AppStore.load()
            XCTAssertEqual(reloaded.styleProfiles.count, 1)
            XCTAssertEqual(reloaded.styleProfiles.first?.name, "冷峻白描")
            XCTAssertEqual(reloaded.styleProfiles.first?.mustRules, ["短句为主"])
            XCTAssertEqual(reloaded.styleProfiles.first?.sampleCharCount, 12_345)
        }
    }

    func testDeleteStyleProfileUnbindsNovels() throws {
        try MainActor.assumeIsolated {
            let store = AppStore()
            let novel = Novel(title: "绑定书")
            let profile = StyleProfile(name: "待删档案")
            store.novels.append(novel)
            store.styleProfiles.append(profile)
            novel.activeStyleProfileID = profile.id

            store.deleteStyleProfile(profile)
            XCTAssertTrue(store.styleProfiles.isEmpty)
            XCTAssertNil(store.novels.first?.activeStyleProfileID)
        }
    }
}

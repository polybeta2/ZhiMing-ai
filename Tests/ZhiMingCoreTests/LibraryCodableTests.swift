import XCTest
@testable import ZhiMingCore

/// 持久层 Codable：对象图往返 + 旧档字段兼容（library.json 是唯一用户数据，兼容性是底线）
final class LibraryCodableTests: XCTestCase {

    /// Novel 全对象图 encode → decode 往返，关键字段不丢失
    func testNovelGraphRoundtrip() throws {
        let novel = Fixtures.makeNovel()
        let chapter = Fixtures.targetChapter(in: novel)
        chapter.snapshots = [ChapterSnapshot(versionNumber: 1, content: "旧稿", triggerType: "manual_save")]

        let data = try JSONEncoder().encode(novel)
        let back = try JSONDecoder().decode(Novel.self, from: data)

        XCTAssertEqual(back.title, "雾港来信")
        XCTAssertEqual(back.styleGuide, novel.styleGuide)
        XCTAssertEqual(back.volumes.count, 2)
        let backTarget = try XCTUnwrap(back.sortedVolumes[1].sortedChapters.first)
        XCTAssertEqual(backTarget.title, "第三章 潜入")
        XCTAssertEqual(backTarget.sceneCards?.first?.goal, "拿到印刷批次记录")
        XCTAssertEqual(backTarget.summary?.keyFacts ?? [], [])   // 目标章本身无摘要
        XCTAssertEqual(back.sortedVolumes[0].sortedChapters[0].summary?.summaryText,
                       "沈屿收到一封署名亡者的信。")
        XCTAssertEqual(back.characters.first?.aliases, ["沈探长"])
        XCTAssertEqual(back.worldEntries.first?.name, "旧纸坊")
        XCTAssertEqual(back.foreshadowings.first?.title, "烧毁的印刷机")
        // 反向引用在解码后重建
        XCTAssertTrue(backTarget.volume === back.sortedVolumes[1])
        XCTAssertEqual(backTarget.snapshots.first?.content, "旧稿")
    }

    /// 旧档兼容：无 skipsClarification 字段的 ChatThread 解码为 false（v2.2.1 新字段）
    func testChatThreadLegacyJSONDefaultsSkipsClarification() throws {
        let thread = ChatThread(purpose: "creation")
        thread.skipsClarification = true
        thread.messages = [ChatMessage(role: "user", content: "完整思路……")]

        let data = try JSONEncoder().encode(thread)
        var doc = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        doc.removeValue(forKey: "skipsClarification")          // 模拟 v2.2.0 及更早的存档
        let legacy = try JSONSerialization.data(withJSONObject: doc)

        let back = try JSONDecoder().decode(ChatThread.self, from: legacy)
        XCTAssertEqual(back.purpose, "creation")
        XCTAssertFalse(back.skipsClarification)
        XCTAssertEqual(back.messages.first?.content, "完整思路……")
    }

    /// skipsClarification=true 必须保真往返（完整思路立项模式的恢复依赖它）
    func testSkipsClarificationRoundtrip() throws {
        let thread = ChatThread(purpose: "creation")
        thread.skipsClarification = true
        let data = try JSONEncoder().encode(thread)
        let back = try JSONDecoder().decode(ChatThread.self, from: data)
        XCTAssertTrue(back.skipsClarification)
    }

    /// AppStore 存取往返：临时目录隔离，验证 library.json 原子写 + 重载
    func testAppStoreSaveLoadRoundtrip() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("zm-tests-\(UUID().uuidString)", isDirectory: true)
        try MainActor.assumeIsolated {
            AppStore.directoryOverride = tmp
            defer { AppStore.directoryOverride = nil }

            let store = AppStore()
            store.novels = [Fixtures.makeNovel()]
            store.save()

            let reloaded = AppStore.load()
            XCTAssertEqual(reloaded.novels.count, 1)
            XCTAssertEqual(reloaded.novels.first?.title, "雾港来信")
            XCTAssertEqual(reloaded.novels.first?.sortedVolumes.count, 2)
        }
    }

    /// 卷章四维结构（情绪走向/冲突阶梯/信息差）往返
    func testVolumeDimensionsRoundtrip() throws {
        let volume = Fixtures.makeNovel().sortedVolumes[0]
        volume.emotionArc = ["压抑", "爆发"]
        volume.conflictLadder = [ConflictRung(level: 1, obstacle: "排挤", turningPoint: "翻案")]
        volume.infoGap = InfoGap(start: "不知情", end: "全知")

        let data = try JSONEncoder().encode(volume)
        let back = try JSONDecoder().decode(Volume.self, from: data)
        XCTAssertEqual(back.emotionArc, ["压抑", "爆发"])
        XCTAssertEqual(back.conflictLadder?.first?.turningPoint, "翻案")
        XCTAssertEqual(back.infoGap?.start, "不知情")
    }
}

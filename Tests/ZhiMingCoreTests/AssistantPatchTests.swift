import XCTest
@testable import ZhiMingCore

/// 写作助手 zm-patch 补丁协议：提取/剥离/误判防护
final class AssistantPatchTests: XCTestCase {

    private let patchJSON = """
    {"character_updates": [{"find": "沈屿", "set": {"currentGoal": "盯住纸坊"}}]}
    """

    func testExtractFromZmPatchFence() throws {
        let reply = "好的，已根据讨论更新设定。\n```zm-patch\n\(patchJSON)\n```\n以上修改请确认。"
        let (patch, cleaned) = AssistantPatch.extract(in: reply)
        let p = try XCTUnwrap(patch)
        XCTAssertEqual(p.character_updates?.first?.find, "沈屿")
        XCTAssertEqual(p.character_updates?.first?.set["currentGoal"], "盯住纸坊")
        XCTAssertFalse(cleaned.contains("zm-patch"))
        XCTAssertFalse(cleaned.contains("character_updates"))
        XCTAssertTrue(cleaned.contains("以上修改请确认。"))
    }

    /// 无围栏时的兜底：全文首个 {…} 裸对象
    func testExtractFromBareJSONFallback() throws {
        let reply = "更新如下：{\"volume_renames\": [{\"find\": \"第一卷\", \"to\": \"雾起\"}]}"
        let (patch, cleaned) = AssistantPatch.extract(in: reply)
        let p = try XCTUnwrap(patch)
        XCTAssertEqual(p.volume_renames?.first?.to, "雾起")
        XCTAssertFalse(cleaned.contains("volume_renames"))
    }

    /// 普通回复（无有效变更字段）不得误判为补丁
    func testPlainTextUntouched() {
        let reply = "这一章的节奏可以再收紧一些。"
        let (patch, cleaned) = AssistantPatch.extract(in: reply)
        XCTAssertNil(patch)
        XCTAssertEqual(cleaned, reply)
    }

    /// 仅含 summary 的对象不算补丁（防误判普通 JSON 回复）
    func testSummaryOnlyObjectNotAPatch() {
        let reply = "说明：{\"summary\": \"只是解释\"}"
        let (patch, cleaned) = AssistantPatch.extract(in: reply)
        XCTAssertNil(patch)
        XCTAssertEqual(cleaned, reply)
    }

    /// 围栏内 JSON 损坏：返回原文
    func testBrokenJSONInFenceReturnsOriginal() {
        let reply = "尝试修改：\n```zm-patch\n{character_updates: 残缺}\n```"
        let (patch, cleaned) = AssistantPatch.extract(in: reply)
        XCTAssertNil(patch)
        XCTAssertEqual(cleaned, reply)
    }

    /// 角色定位：精确名 / 别名 / 双向包含
    func testMatchCharacterByExactNameAliasAndFuzzy() {
        let novel = Fixtures.makeNovel()
        XCTAssertEqual(AssistantPatch.matchCharacter("沈屿", in: novel)?.name, "沈屿")
        XCTAssertEqual(AssistantPatch.matchCharacter("沈探长", in: novel)?.name, "沈屿")
        XCTAssertEqual(AssistantPatch.matchCharacter("沈屿探长", in: novel)?.name, "沈屿")
        XCTAssertNil(AssistantPatch.matchCharacter("路人甲", in: novel))
    }

    /// 卷定位：支持「第N卷」前缀
    func testMatchVolumeWithOrdinalPrefix() {
        let novel = Fixtures.makeNovel()
        XCTAssertEqual(AssistantPatch.matchVolume("第一卷 雾起", in: novel)?.name, "第一卷 雾起")
        XCTAssertEqual(AssistantPatch.matchVolume("第1卷", in: novel)?.name, "第一卷 雾起")
        XCTAssertNil(AssistantPatch.matchVolume("第三卷", in: novel))
    }

    /// 只有含至少一项实际变更的对象才算补丁（isEmptyPatch 语义经由 extract 验证）
    func testEmptyObjectJSONIsNotAPatch() {
        let reply = "配置示例：{}"
        let (patch, _) = AssistantPatch.extract(in: reply)
        XCTAssertNil(patch)
    }
}

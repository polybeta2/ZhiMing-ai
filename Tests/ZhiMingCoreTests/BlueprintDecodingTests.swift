import XCTest
@testable import ZhiMingCore

/// 蓝图解码容错：历次真实 LLM 输出事故的回归测试（v2.1.2 起）
final class BlueprintDecodingTests: XCTestCase {

    /// v2.1.2 根因回归：conflict_ladder 被输出为字符串数组（与 emotion_arc 混淆），
    /// 严格 Codable 整单失败；字符串应容错进首字段 obstacle
    func testConflictLadderStringArrayTolerance() throws {
        let json = """
        {
          "title_suggestion": "雾港来信",
          "volumes": [
            {"name": "第一卷", "conflict_ladder": ["外敌压境", "帮派倾轧"]}
          ]
        }
        """
        let bp = try JSONDecoder().decode(NovelBlueprint.self, from: Data(json.utf8))
        XCTAssertEqual(bp.volumes.count, 1)
        let ladder = try XCTUnwrap(bp.volumes[0].conflict_ladder)
        XCTAssertEqual(ladder.count, 2)
        XCTAssertEqual(ladder[0].obstacle, "外敌压境")
        XCTAssertNil(ladder[0].level)
        XCTAssertNil(ladder[0].turning_point)
        XCTAssertEqual(ladder[1].obstacle, "帮派倾轧")
    }

    /// 正常形态：对象数组逐字段解码
    func testConflictLadderObjectArray() throws {
        let json = """
        {"volumes": [{"name": "V1", "conflict_ladder": [
            {"level": 1, "obstacle": "船税案", "turning_point": "伪证曝光"}
        ]}]}
        """
        let bp = try JSONDecoder().decode(NovelBlueprint.self, from: Data(json.utf8))
        let rung = try XCTUnwrap(bp.volumes[0].conflict_ladder?.first)
        XCTAssertEqual(rung.level, 1)
        XCTAssertEqual(rung.obstacle, "船税案")
        XCTAssertEqual(rung.turning_point, "伪证曝光")
    }

    /// 场景卡字符串容错：字符串按首字段 goal 处理
    func testSceneCardStringTolerance() throws {
        let json = """
        {"volumes": [{"name": "V1", "chapters": [
            {"title": "第一章", "scene_cards": ["主角潜入档案馆"]}
        ]}]}
        """
        let bp = try JSONDecoder().decode(NovelBlueprint.self, from: Data(json.utf8))
        let card = try XCTUnwrap(bp.volumes[0].chapters[0].scene_cards?.first)
        XCTAssertEqual(card.goal, "主角潜入档案馆")
        XCTAssertNil(card.obstacle)
        XCTAssertNil(card.hook)
    }

    /// 完整蓝图（snake_case 契约字段）+ info_gap 混合形态
    func testFullBlueprintDecoding() throws {
        let json = """
        {
          "title_suggestion": "雾港来信",
          "theme": "执念与救赎",
          "synopsis": "一封来自死者的信",
          "perspective": "第三人称限知",
          "style_guide": "冷峻克制",
          "characters": [{"name": "沈屿", "role": "主角", "goal": "查清寄信人"}],
          "worldbuilding": [{"category": "地点", "name": "雾港", "content": "终年多雾"}],
          "volumes": [
            {"name": "第一卷 雾起", "outline": "开案",
             "emotion_arc": ["压抑", "紧绷"],
             "conflict_ladder": [{"level": 1, "obstacle": "排挤", "turning_point": "翻案"}],
             "info_gap": {"start": "读者不知寄信人", "end": "揭示首匿名者"},
             "chapters": [{"title": "死信", "detailed_outline": "收信",
                           "foreshadowings": [{"title": "火漆印"}]}]
            }
          ]
        }
        """
        let bp = try JSONDecoder().decode(NovelBlueprint.self, from: Data(json.utf8))
        XCTAssertEqual(bp.title_suggestion, "雾港来信")
        XCTAssertEqual(bp.theme, "执念与救赎")
        XCTAssertEqual(bp.characters.first?.name, "沈屿")
        XCTAssertEqual(bp.worldbuilding.first?.category, "地点")
        let vol = try XCTUnwrap(bp.volumes.first)
        XCTAssertEqual(vol.emotion_arc, ["压抑", "紧绷"])
        XCTAssertEqual(vol.info_gap?.end, "揭示首匿名者")
        XCTAssertEqual(vol.chapters.first?.foreshadowings?.first?.title, "火漆印")
    }

    /// 全空对象：字段全可缺省
    func testEmptyBlueprintTolerance() throws {
        let bp = try JSONDecoder().decode(NovelBlueprint.self, from: Data("{}".utf8))
        XCTAssertTrue(bp.characters.isEmpty)
        XCTAssertTrue(bp.volumes.isEmpty)
        XCTAssertNil(bp.title_suggestion)
    }

    /// 澄清/结构提案结构
    func testClarifyAndProposal() throws {
        let clarify = try JSONDecoder().decode(ClarifyResult.self, from: Data(
            #"{"enough": true, "reason": "信息足够", "questions": []}"#.utf8))
        XCTAssertEqual(clarify.enough, true)

        let proposal = try JSONDecoder().decode(StructureProposal.self, from: Data(
            #"{"concept": "雾港探案", "volumes": [{"name": "雾起", "chapter_count": 12}]}"#.utf8))
        XCTAssertEqual(proposal.volumes.first?.chapter_count, 12)
    }

    /// 会话快照往返（SQLite 缓存里的 payload 形态）
    func testCreationSessionStateRoundtrip() throws {
        var bp = NovelBlueprint()
        bp.title_suggestion = "雾港来信"
        bp.volumes = [BlueprintVolume(name: "第一卷")]
        let state = CreationSessionState(phaseRaw: "blueprintReady", brief: "一句话创意",
                                         qaText: "问：…\n答：…",
                                         proposal: StructureProposal(concept: "c", volumes: []),
                                         blueprint: bp, volumesPerBatch: 3, chaptersPerBatch: 2,
                                         autoContinue: false)
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(CreationSessionState.self, from: data)
        XCTAssertEqual(back.phaseRaw, "blueprintReady")
        XCTAssertEqual(back.brief, "一句话创意")
        XCTAssertEqual(back.blueprint?.title_suggestion, "雾港来信")
        XCTAssertEqual(back.blueprint?.volumes.first?.name, "第一卷")
    }
}

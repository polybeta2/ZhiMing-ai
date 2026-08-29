import XCTest
@testable import ZhiMingCore

final class StyleFusionTests: XCTestCase {
    private func makeProfile(_ name: String, temperature: String, shape: String,
                             register: String, openings: String, subtext: String,
                             directness: String, forbidden: [String]) -> StyleProfile {
        let p = StyleProfile(name: name)
        p.tags = [name]
        p.fingerprintSummary = "\(name) 的小结"
        p.mustRules = ["\(name) 规则A"]
        p.avoidRules = ["\(name) 禁忌A"]
        p.narrativeVoice.temperature = temperature
        p.sentenceSyntax.shape = shape
        p.diction.register = register
        p.diction.bannedMoves = ["\(name) 套话"]
        p.sceneRhythm.openings = openings
        p.dialogue.subtextLevel = subtext
        p.emotion.directness = directness
        p.antiAI.forbiddenPatterns = forbidden
        p.examples = [StyleExample(plain: "x", styled: "\(name) 示范", principle: "p")]
        return p
    }

    private func fuse() throws -> (StyleProfile, StyleProfile, StyleProfile, StyleProfile) {
        let a = makeProfile("冷雨", temperature: "冷峻", shape: "短句", register: "口语",
                            openings: "直接入戏", subtext: "高潜台词", directness: "移置",
                            forbidden: ["不是…而是…"])
        let b = makeProfile("绵长", temperature: "温润", shape: "长句", register: "书面",
                            openings: "景物起手", subtext: "直白", directness: "直陈",
                            forbidden: ["AI 腔", "排比抒情"])
        let choices = StyleFusion.LayerChoices(
            voice: a.id, syntax: b.id, diction: b.id,
            rhythm: a.id, dialogue: b.id, emotion: a.id)
        let fused = try XCTUnwrap(StyleFusion.fuse(name: "冷雨绵长体", base: a, participants: [a, b], choices: choices))
        return (fused, a, b, b)   // b 返回两次仅为占位
    }

    func testFusionPicksLayersByChoice() throws {
        let (fused, a, b, _) = try fuse()
        XCTAssertEqual(fused.narrativeVoice.temperature, "冷峻", "voice 取 A")
        XCTAssertEqual(fused.sentenceSyntax.shape, "长句", "syntax 取 B")
        XCTAssertEqual(fused.diction.register, "书面", "diction 取 B")
        XCTAssertEqual(fused.sceneRhythm.openings, "直接入戏", "rhythm 取 A")
        XCTAssertEqual(fused.dialogue.subtextLevel, "直白", "dialogue 取 B")
        XCTAssertEqual(fused.emotion.directness, "移置", "emotion 取 A")
        XCTAssertNotEqual(fused.id, a.id, "融合产出全新档案")
        XCTAssertEqual(fused.name, "冷雨绵长体")
        XCTAssertEqual(fused.confidence, "low", "合成档案置信度保守标注")
        XCTAssertTrue(fused.sourceNote.contains("2 份档案"))
    }

    func testFusionUnionsAntiAIAndRules() throws {
        let (fused, a, b, _) = try fuse()
        XCTAssertTrue(fused.antiAI.forbiddenPatterns.contains("不是…而是…"))
        XCTAssertTrue(fused.antiAI.forbiddenPatterns.contains("AI 腔"))
        XCTAssertTrue(fused.antiAI.forbiddenPatterns.contains("排比抒情"))
        XCTAssertTrue(fused.diction.bannedMoves.contains("冷雨 套话"))
        XCTAssertTrue(fused.diction.bannedMoves.contains("绵长 套话"))
        XCTAssertEqual(fused.mustRules, ["冷雨 规则A", "绵长 规则A"])
        XCTAssertEqual(fused.avoidRules, ["冷雨 禁忌A", "绵长 禁忌A"])
        XCTAssertEqual(fused.tags, ["冷雨", "绵长"])
        XCTAssertEqual(fused.examples.first?.styled, "冷雨 示范", "示范对照取基底档案")
    }

    func testFusionFailsOnUnknownChoice() {
        let a = makeProfile("A", temperature: "t", shape: "s", register: "r",
                            openings: "o", subtext: "st", directness: "d", forbidden: [])
        let bogus = UUID()
        let choices = StyleFusion.LayerChoices(
            voice: bogus, syntax: a.id, diction: a.id,
            rhythm: a.id, dialogue: a.id, emotion: a.id)
        XCTAssertNil(StyleFusion.fuse(name: "x", base: a, participants: [a], choices: choices))
    }

    func testFusionRequiresBaseInParticipants() {
        let a = makeProfile("A", temperature: "t", shape: "s", register: "r",
                            openings: "o", subtext: "st", directness: "d", forbidden: [])
        let choices = StyleFusion.LayerChoices(
            voice: a.id, syntax: a.id, diction: a.id,
            rhythm: a.id, dialogue: a.id, emotion: a.id)
        XCTAssertNil(StyleFusion.fuse(name: "x", base: a, participants: [], choices: choices))
    }
}

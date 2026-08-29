import XCTest
@testable import ZhiMingCore

final class StyleModelsTests: XCTestCase {
    func testFlexStringArrayAcceptsArrayAndString() throws {
        // 注：合成 Codable 对非可选属性在 key 缺失时直接抛 keyNotFound（不使用属性默认值），
        // 包装器无法拦截。生产模式与子结构一致：手写 init(from:) 用 decodeIfPresent + 包装器兜底。
        struct Box: Decodable {
            enum CodingKeys: String, CodingKey { case items }
            @FlexStringArray var items: [String]
            init() { _items = FlexStringArray() }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                _items = try c.decodeIfPresent(FlexStringArray.self, forKey: .items) ?? FlexStringArray()
            }
        }
        let a = try JSONDecoder().decode(Box.self, from: Data(#"{"items":["甲","乙"]}"#.utf8))
        XCTAssertEqual(a.items, ["甲", "乙"])
        let b = try JSONDecoder().decode(Box.self, from: Data(#"{"items":"甲，乙、丙"}"#.utf8))
        XCTAssertEqual(b.items, ["甲", "乙", "丙"])
        let c = try JSONDecoder().decode(Box.self, from: Data(#"{"items":123}"#.utf8))
        XCTAssertEqual(c.items, [])
        let d = try JSONDecoder().decode(Box.self, from: Data(#"{}"#.utf8))
        XCTAssertEqual(d.items, [])
    }

    func testStyleProfileDecodesMinimalJSON() throws {
        // 旧版本/缺字段 JSON 必须能解出全默认对象（存量兼容铁律）
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"冷峻白描"}"#
        let profile = try JSONDecoder().decode(StyleProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.name, "冷峻白描")
        XCTAssertEqual(profile.mustRules, [])
        XCTAssertEqual(profile.confidence, "medium")
        XCTAssertNil(profile.localMetrics)
    }

    func testStyleProfileCodableRoundtrip() throws {
        var profile = StyleProfile(name: "测试文风")
        profile.tags = ["冷峻", "白描"]
        profile.mustRules = ["每段至多两个形容词"]
        profile.narrativeVoice.pov = "第三人称贴身"
        profile.examples = [StyleExample(plain: "他非常生气", styled: "他把杯子顿在桌上", principle: "情绪外化为动作")]
        let data = try JSONEncoder().encode(profile)
        let back = try JSONDecoder().decode(StyleProfile.self, from: data)
        XCTAssertEqual(back.tags, profile.tags)
        XCTAssertEqual(back.mustRules, profile.mustRules)
        XCTAssertEqual(back.narrativeVoice.pov, "第三人称贴身")
        XCTAssertEqual(back.examples.first?.styled, "他把杯子顿在桌上")
    }
}

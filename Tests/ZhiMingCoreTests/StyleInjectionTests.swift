import XCTest
@testable import ZhiMingCore

/// P1 注入链路测试：文风档案卡在续写/大纲/写作助手三个注入点的装配行为
final class StyleInjectionTests: XCTestCase {
    private func makeCard(_ name: String = "冷峻白描") -> String {
        let profile = StyleProfile(name: name)
        profile.tags = ["冷峻"]
        profile.fingerprintSummary = "短句为主。"
        profile.mustRules = ["每段至多一个比喻"]
        return StyleCardRenderer.render(profile, variant: .writing)
    }

    func testContinueContextInjectsStyleCardAsRequiredLayer() throws {
        let novel = Fixtures.makeNovel()
        guard let chapter = novel.volumes.first?.chapters.first else {
            return XCTFail("fixture 缺少章节")
        }
        // 预算给足：styleCard 应原样进入必需层
        let context = ContextBuilder.buildContinueContext(
            chapter: chapter, novel: novel, budgetChars: 10_000, styleCard: makeCard())
        XCTAssertTrue(context.rendered.contains("【文风档案：冷峻白描】"))
        XCTAssertTrue(context.rendered.contains("必遵规则"))
        // nil 卡不改变行为
        let plain = ContextBuilder.buildContinueContext(
            chapter: chapter, novel: novel, budgetChars: 10_000, styleCard: nil)
        XCTAssertFalse(plain.rendered.contains("【文风档案"))
    }

    func testOutlineContextInjectsStyleCard() throws {
        let novel = Fixtures.makeNovel()
        let volume = try XCTUnwrap(novel.volumes.first)
        let context = ContextBuilder.buildOutlineContext(
            target: .volume(volume), novel: novel, budgetChars: 10_000,
            styleCard: "【文风档案：测试卡】视角：第三人称贴身")
        XCTAssertTrue(context.rendered.contains("【文风档案：测试卡】"))
    }

    func testWritingAssistantSystemAppendsStyleCard() {
        let system = MainActor.assumeIsolated {
            PromptTemplates.writingAssistantSystem(
                title: "雾港来信", synopsis: "一封来自死去之人的信",
                styleGuide: "冷峻克制",
                styleCard: "【文风档案：冷峻白描】必遵规则：\n1. 每段至多一个比喻")
        }
        XCTAssertTrue(system.contains("雾港来信"))
        XCTAssertTrue(system.contains("【文风档案：冷峻白描】"))
        XCTAssertTrue(system.contains("每段至多一个比喻"))
        // 无卡时不追加
        let plain = MainActor.assumeIsolated {
            PromptTemplates.writingAssistantSystem(title: "雾港来信", synopsis: "", styleGuide: nil, styleCard: nil)
        }
        XCTAssertFalse(plain.contains("【文风档案"))
    }
}

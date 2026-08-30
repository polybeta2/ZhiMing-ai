import XCTest
@testable import ZhiMingCore

/// Linux XCTest 的发现机制不支持 @MainActor 测试类（生成代码强转会崩溃），
/// 与 PromptTemplatesTests 同模式：非隔离类 + assumeIsolated 访问 MainActor 单例。
final class StylePromptTests: XCTestCase {
    func testStylePromptIDsRegistered() {
        let texts = MainActor.assumeIsolated {
            [
                PromptLibrary.shared.resolvedText(for: PromptID.styleDistillAnalyze),
                PromptLibrary.shared.resolvedText(for: PromptID.styleDistillCard),
                PromptLibrary.shared.resolvedText(for: PromptID.styleDistillFix),
            ]
        }
        for (id, text) in zip(["analyze", "card", "fix"], texts) {
            XCTAssertFalse(text.isEmpty, "出厂默认文本缺失：\(id)")
        }
    }

    func testAntiAIInlinePromptRegistered() {
        let text = MainActor.assumeIsolated {
            PromptLibrary.shared.resolvedText(for: PromptID.antiAIInline)
        }
        XCTAssertFalse(text.isEmpty, "去AI味·写作时自动约束出厂文本缺失")
        XCTAssertTrue(text.contains("写作时同步遵守"), "必须是写作时约束（而非改写指令）")
        XCTAssertTrue(text.contains("说明腔"), "必须覆盖解释性对举句式规则")
        XCTAssertFalse(text.contains("只输出修改后的正文"), "不得混入改写场景专属指令")
    }

    func testAnalyzePromptContainsGuardrails() {
        let text = MainActor.assumeIsolated {
            PromptLibrary.shared.resolvedText(for: PromptID.styleDistillAnalyze)
        }
        XCTAssertTrue(text.contains("内容层"), "必须包含内容层排除铁律")
        XCTAssertTrue(text.contains("JSON"), "必须要求 JSON 输出")
    }

    func testRenderSupportsStylePlaceholders() {
        let out = MainActor.assumeIsolated {
            PromptLibrary.render("样本：{styleSample} 计量：{styleMetrics}", values: ["styleSample": "S", "styleMetrics": "M"])
        }
        XCTAssertEqual(out, "样本：S 计量：M")
    }

    func testStyleLimitsDefined() {
        XCTAssertGreaterThan(PromptLimits.styleProfileCap, 0)
        XCTAssertGreaterThan(PromptLimits.styleProfileOutlineCap, 0)
        XCTAssertGreaterThan(PromptLimits.styleProfileAntiAICap, 0)
        XCTAssertGreaterThan(PromptLimits.styleSampleCap, 0)
        XCTAssertGreaterThan(PromptLimits.styleEvidenceCap, 0)
    }
}

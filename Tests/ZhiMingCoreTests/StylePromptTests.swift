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

import XCTest
@testable import ZhiMingCore

/// 消息装配器：注入顺序（模板 → 附加指令）与预算扣减
/// PromptTemplates 是 @MainActor 单例装配器，测试经 assumeIsolated 调用
final class PromptTemplatesTests: XCTestCase {

    func testCreationClarifyAssembly() {
        let messages = MainActor.assumeIsolated {
            PromptTemplates.creationClarify(brief: "写一个雾港探案故事", qaHistory: "", supplement: nil)
        }
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertTrue(messages[1].content.contains("雾港探案"))
    }

    /// 附加指令拼接进首条 system，而非新增消息
    func testProviderExtraAppendsToSystemMessage() {
        let base = [LLMMessage(role: .system, content: "系统提示词"),
                    LLMMessage(role: .user, content: "用户输入")]
        let withExtra = MainActor.assumeIsolated {
            PromptTemplates.applying(providerExtra: "  保持冷峻文风  ", to: base)
        }
        XCTAssertEqual(withExtra.count, 2)
        XCTAssertTrue(withExtra[0].content.hasPrefix("系统提示词"))
        XCTAssertTrue(withExtra[0].content.contains("保持冷峻文风"))
        XCTAssertEqual(withExtra[1].content, "用户输入")
    }

    /// 无首条 system 时附加指令插入为新的首条
    func testProviderExtraInsertsSystemWhenMissing() {
        let base = [LLMMessage(role: .user, content: "用户输入")]
        let withExtra = MainActor.assumeIsolated {
            PromptTemplates.applying(providerExtra: "附加指令", to: base)
        }
        XCTAssertEqual(withExtra.count, 2)
        XCTAssertEqual(withExtra[0].role, .system)
        XCTAssertEqual(withExtra[0].content, "附加指令")
    }

    func testEmptyOrWhitespaceExtraIsNoop() {
        let base = [LLMMessage(role: .user, content: "x")]
        MainActor.assumeIsolated {
            XCTAssertEqual(PromptTemplates.applying(providerExtra: nil, to: base).count, 1)
            XCTAssertEqual(PromptTemplates.applying(providerExtra: "   \n ", to: base).count, 1)
        }
    }

    func testAdjustedInputBudgetSubtractsInjections() {
        MainActor.assumeIsolated {
            XCTAssertEqual(PromptTemplates.adjustedInputBudget(base: 1000, injections: "12345", nil, "ab"), 993)
            XCTAssertEqual(PromptTemplates.adjustedInputBudget(base: 10, injections: "12345678901234"), 0)
        }
    }

    func testWritingAssistantSystemIncludesNovelContext() {
        let system = MainActor.assumeIsolated {
            PromptTemplates.writingAssistantSystem(title: "雾港来信", synopsis: "一封来自死者的信", styleGuide: "冷峻")
        }
        XCTAssertTrue(system.contains("雾港来信"))
        XCTAssertTrue(system.contains("一封来自死者的信"))
        XCTAssertTrue(system.contains("冷峻"))
    }

    /// 立项结构提案装配：brief 与问答历史都进 user 消息
    func testCreationStructureAssembly() {
        let messages = MainActor.assumeIsolated {
            PromptTemplates.creationStructure(brief: "雾港探案", qaHistory: "问：主角是谁？\n答：沈屿。",
                                              feedback: nil, supplement: nil)
        }
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages[1].content.contains("雾港探案"))
        XCTAssertTrue(messages[1].content.contains("沈屿"))
    }
}

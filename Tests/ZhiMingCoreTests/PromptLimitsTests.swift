import XCTest
@testable import ZhiMingCore

/// 体量护栏常量（v1.7 引入的全局字符预算，逐值锁定防回归）
final class PromptLimitsTests: XCTestCase {

    /// v2.2.1 锁定：v2.2.0 曾放宽到 200K 后回退 v1.7 语义
    func testRequestWarnCharsLockedAt80K() {
        XCTAssertEqual(PromptLimits.requestWarnChars, 80_000)
    }

    func testAllGuardsUnchanged() {
        XCTAssertEqual(PromptLimits.maxOverrideChars, 20_000)
        XCTAssertEqual(PromptLimits.maxTagPresetChars, 20_000)
        XCTAssertEqual(PromptLimits.matchedSupplementCap, 8_000)
        XCTAssertEqual(PromptLimits.r18ModuleCharBudget, 12_000)
        XCTAssertEqual(PromptLimits.requiredFieldCap, 4_000)
        XCTAssertEqual(PromptLimits.historyMessageCap, 2_000)
        XCTAssertEqual(PromptLimits.foreshadowReminderChapterThreshold, 8)
        XCTAssertEqual(PromptLimits.foreshadowReminderCap, 2_000)
        XCTAssertEqual(PromptLimits.foreshadowTextFieldCap, 2_000)
    }

    /// 互相约束的护栏之间保持合理关系
    func testGuardRelationships() {
        XCTAssertLessThan(PromptLimits.requiredFieldCap, PromptLimits.matchedSupplementCap)
        XCTAssertLessThan(PromptLimits.matchedSupplementCap, PromptLimits.r18ModuleCharBudget)
        XCTAssertLessThan(PromptLimits.historyMessageCap, PromptLimits.requiredFieldCap)
    }
}

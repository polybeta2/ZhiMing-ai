import XCTest
@testable import ZhiMingCore

/// 本地文风快检（去 AI 味）：只报告不改正文
final class ProseCheckerTests: XCTestCase {

    /// 过短样本不做统计
    func testShortTextSkipped() {
        XCTAssertTrue(ProseChecker.check("太短了。").isEmpty)
    }

    func testClicheAndExplainingToneDetected() {
        let text = """
        他不是不想帮她，而是不知道怎么开口。她瞳孔一缩，倒吸一口凉气。
        这仿佛是一场审判，又犹如一场梦。他的心中涌起一股暖流，仿佛回到从前。
        她眼中闪过一丝惊讶，喉结滚动，指尖微颤。他心里清楚，这不是巧合。
        他意识到门没有锁。窗外的雨停了，街灯亮起来。
        长街尽头有人在唱歌，声音沙哑。他忽然明白，有些告别不会第二次发生。
        """
        let issues = ProseChecker.check(text)
        let rules = issues.map(\.rule)
        XCTAssertTrue(rules.contains("解释性对举句"))
        XCTAssertTrue(rules.contains("模板动作套话"))
        XCTAssertTrue(rules.contains("比喻滥用"))
        XCTAssertTrue(rules.contains("认知直陈"))
    }

    /// 口语化、句长错落的正常文本不应触发任何规则
    func testCleanVariedTextPasses() {
        let text = """
        雨停了。他推门出去，巷口的积水映着灯。
        老周蹲在台阶上抽烟，看见他，抬了抬下巴。
        两个人都没说话。风把桌上的纸吹起来，他伸手按住，纸上是三天前的账。
        数字对不上，差两百块，不多，但足够让人夜里睡不着。
        老周把烟按灭在鞋底，说明早去趟码头，把这事问清楚。
        他点头，转身回屋收拾雨衣和手电。
        巷子深处传来狗叫，一声接一声，像是给谁报信。
        码头那边今天卸货，人手多，去晚了一句实话也问不出来。
        他把两件东西塞进包里，又把门锁了三道。
        出门时天还没亮，路灯照着他的影子，拉得很长。
        """
        let issues = ProseChecker.check(text)
        XCTAssertEqual(issues, [], "意外命中：\(issues.map { $0.rule })")
    }

    func testReportLinesFormatAndCap() {
        let text = String(repeating: "她瞳孔一缩，倒吸一口凉气。仿佛一切早已注定，犹如宿命。", count: 8)
        let lines = ProseChecker.reportLines(in: text, maxLines: 2)
        XCTAssertLessThanOrEqual(lines.count, 2)
        XCTAssertTrue(lines.allSatisfy { $0.hasPrefix("- ") })
    }
}

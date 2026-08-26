import Foundation

/// 本地「文风快检」：纯文本统计，零 LLM 成本，为「去 AI 味」改写提供问题清单。
/// 铁律与上游方法论一致：只报告、不改正文；警告仅供提示，不作硬门槛。
/// 检测规则为本项目自行编写（分级思想参考 awesome-novel-agent 的做法，措辞未复制其文本）。
enum ProseChecker {

    struct Issue: Identifiable, Equatable {
        let id = UUID()
        let rule: String        // 规则名
        let detail: String      // 命中情况说明
    }

    // MARK: 检测配置（自写词表，可按需扩充）

    /// 高频模板动作/神态套话：出现即报告
    private static let clichePhrases: [(phrase: String, advice: String)] = [
        ("瞳孔", "换成可观察的具体反应"),
        ("倒吸一口凉气", "改为动作或沉默"),
        ("倒吸凉气", "改为动作或沉默"),
        ("勾起一抹", "删掉程式化笑意描写"),
        ("嘴角勾起", "换具体笑法或省略"),
        ("眼中闪过", "改为可见行为"),
        ("眼底闪过", "改为可见行为"),
        ("心中涌起", "情绪外化为动作"),
        ("一股暖流", "改为具体身体感受"),
        ("喉结滚动", "减少特写式套件"),
        ("指尖微颤", "减少特写式套件"),
        ("深吸一口气", "同段多次才需要替换"),
    ]

    /// 过渡套话：同段聚集才明显
    private static let transitionPhrases = ["与此同时", "刹那间", "霎时间", "瞬间，"]

    private static func countMatches(in text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    // MARK: 主入口

    /// 返回问题清单（每条一行可读文本）；无命中返回空数组。
    static func reportLines(in text: String, maxLines: Int = 8) -> [String] {
        check(text).prefix(maxLines).map { "- \($0.rule)：\($0.detail)" }
    }

    static func check(_ text: String) -> [Issue] {
        var issues: [Issue] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 60 else { return issues }   // 过短样本不做统计

        // 1) 解释性对举句式（“不是……而是……”说明腔）
        let duiju = countMatches(in: text, pattern: "不是[^。！？\n]{1,16}[，,]?而是")
        if duiju > 0 {
            issues.append(Issue(rule: "解释性对举句",
                                detail: "命中 \(duiju) 处「不是…而是…」式说明腔，建议改由画面直接呈现"))
        }

        // 2) 万能比喻开头
        let simile = countMatches(in: text, pattern: "仿佛|犹如|宛如|好似")
        if simile >= 3 {
            issues.append(Issue(rule: "比喻滥用",
                                detail: "「仿佛/犹如/宛如」出现 \(simile) 次，保留至多一处必要的"))
        }

        // 3) 强加因果（让/令/使 + 抽象感受）
        let causation = countMatches(in: text, pattern: "[让令使][人他她它][^。！？\n]{0,6}(感到|不禁|生出|产生)")
        if causation > 0 {
            issues.append(Issue(rule: "强加因果",
                                detail: "「让/令/使 + 感受」结构 \(causation) 处，改为角色自身的动作反应"))
        }

        // 4) 认知动词直陈心理
        let cognition = countMatches(in: text, pattern: "意识到|心中一凛|内心深处|心里清楚")
        if cognition >= 2 {
            issues.append(Issue(rule: "认知直陈",
                                detail: "「意识到/心中一凛」类 \(cognition) 处，用身体反应与环境互动外化"))
        }

        // 5) 模板动作套话
        var clicheHits: [String] = []
        for (phrase, _) in clichePhrases where text.contains(phrase) {
            clicheHits.append(phrase)
        }
        if !clicheHits.isEmpty {
            issues.append(Issue(rule: "模板动作套话",
                                detail: "命中 \(clicheHits.prefix(4).joined(separator: "、"))等，替换为符合人物的具体小动作"))
        }

        // 6) 过渡套话聚集
        var transitionTotal = 0
        for phrase in transitionPhrases {
            transitionTotal += countMatches(in: text, pattern: NSRegularExpression.escapedPattern(for: phrase))
        }
        if transitionTotal >= 3 {
            issues.append(Issue(rule: "过渡套话",
                                detail: "「与此同时/刹那间」类出现 \(transitionTotal) 次，多数可直接删除或换具体时序"))
        }

        // 7) 句长节奏均一（变异系数过低）
        let sentences = splitSentences(text)
        if sentences.count >= 8 {
            let lengths = sentences.map(\.count)
            let totalLength = lengths.reduce(0, +)
            let mean = Double(totalLength) / Double(lengths.count)
            var squaredDiffSum = 0.0
            for len in lengths {
                let diff = Double(len) - mean
                squaredDiffSum += diff * diff
            }
            let variance = squaredDiffSum / Double(lengths.count)
            let cv = mean > 0 ? variance.squareRoot() / mean : 0
            if cv < 0.35 {
                issues.append(Issue(rule: "句长均一",
                                    detail: String(format: "句长变异系数 %.2f（<0.35 即偏机械），请长短句交替", cv)))
            }
        }

        // 8) “了”字密度过高
        let leCount = countMatches(in: text, pattern: "了")
        let density = Double(leCount) / Double(max(trimmed.count, 1))
        if density > 0.03 {
            issues.append(Issue(rule: "「了」密度偏高",
                                detail: String(format: "占比 %.1f%%，部分可改为完成态描述或直接动词", density * 100)))
        }

        return issues
    }

    private static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "。！？\n".contains(ch) {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { result.append(t) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result.filter { $0.count >= 2 }
    }
}

import Foundation

/// 续写档案 → 注入文本：人物现状快照 + 未回收伏笔 + 剧情弧 + 世界设定 + 近期原文（文风锚点）。
/// 蓝图/细纲/写作共用（SourceScanInjection 两个入口统一分发）。
public enum ContinuationContext {

    public static func rendered(profile: SourceNovelProfile, recentText: String?, maxChars: Int) -> String {
        var lines: [String] = []
        let upTo = profile.continuationFromChapter ?? 0
        lines.append("【续写模式：已分析原作前 \(upTo) 章，从第 \(upTo + 1) 章起无缝续写】")
        if !profile.characters.isEmpty {
            lines.append("【人物现状（截至第 \(upTo) 章）】")
            for c in profile.characters {
                var card = "◆ \(c.name)"
                if let role = c.role, !role.isEmpty { card += "〔\(role)〕" }
                lines.append(card)
                if let state = c.currentState, !state.isEmpty {
                    lines.append("  现状：\(state)")
                } else if let oneLine = c.oneLine, !oneLine.isEmpty {
                    lines.append("  定位：\(oneLine)")
                }
                if let abilities = c.abilities, !abilities.isEmpty { lines.append("  能力：\(abilities)") }
                let relations = c.relationships
                    .filter { !$0.target.isEmpty }
                    .map { "\($0.target)（\($0.relation)）" }
                if !relations.isEmpty { lines.append("  关系：\(relations.joined(separator: "、"))") }
            }
        }
        if !profile.openThreads.isEmpty {
            lines.append("【未回收伏笔（续写应优先安排回收）】")
            for t in profile.openThreads {
                var line = "◆ \(t.title)"
                if let ch = t.plantedChapter { line += "（埋于第 \(ch) 章）" }
                if !t.detail.isEmpty { line += "：\(t.detail)" }
                if !t.participants.isEmpty { line += "〔\(t.participants.joined(separator: "、"))〕" }
                lines.append(line)
            }
        }
        if let arc = profile.plotArc, !arc.isEmpty {
            lines.append("【剧情弧与走向势能】")
            lines.append(arc)
        }
        if !profile.worldbuilding.isEmpty {
            lines.append("【世界设定】")
            for w in profile.worldbuilding.prefix(6) {
                lines.append("- [\(w.category)] \(w.name)：\(w.content)")
            }
        }
        if let recent = recentText, !recent.isEmpty {
            lines.append("【近期原文（文风锚点：严格模仿其叙事节奏、对话口吻与语气词；续写须无缝衔接前文情节）】")
            lines.append(recent)
        }
        var text = lines.joined(separator: "\n")
        if text.count > maxChars {
            let marker = "……（已截断）"
            text = String(text.prefix(max(0, maxChars - marker.count))) + marker
        }
        return text
    }
}
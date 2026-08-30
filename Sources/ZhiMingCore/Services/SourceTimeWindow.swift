import Foundation

/// 原作时间窗：按原作阶段（phase）抽取「该阶段的人物 + 事件 + 设定」，
/// 供卷纲/细纲/写作按需注入（全书档案不整包塞，压 token 且防止后期信息过早出现）。
/// 缺 phase 时回退全量 major 事件 + 全部人物卡。
public struct SourceTimeWindow: Equatable {
    public let phase: String?
    public let characters: [CanonCharacter]
    public let events: [CanonEvent]
    public let worldbuilding: [CanonWorldEntry]

    public init(phase: String?, characters: [CanonCharacter] = [],
                events: [CanonEvent] = [], worldbuilding: [CanonWorldEntry] = []) {
        self.phase = phase
        self.characters = characters
        self.events = events
        self.worldbuilding = worldbuilding
    }

    /// 按 phase 开窗：角色取「arc 含该阶段」+「该 phase 事件参与」并集；
    /// phase 为空/查无此阶段时回退全量档案（major 事件 + 全部人物卡）。
    public static func window(phase: String?, profile: SourceNovelProfile) -> SourceTimeWindow {
        let fallback = SourceTimeWindow(
            phase: nil,
            characters: profile.characters,
            events: profile.timeline.filter { $0.importance == .major },
            worldbuilding: profile.worldbuilding
        )
        guard let phase = phase?.trimmingCharacters(in: .whitespacesAndNewlines), !phase.isEmpty else {
            return fallback
        }
        let events = profile.timeline.filter { ($0.phase ?? "") == phase }
        let hasPhaseMatch = !events.isEmpty
            || profile.characters.contains { $0.arc.contains { $0.stage == phase } }
        guard hasPhaseMatch else { return fallback }
        let participantNames = Set(events.flatMap(\.participants))
        let arcNames = Set(profile.characters
            .filter { $0.arc.contains { $0.stage == phase } }
            .map(\.name))
        let characters = profile.characters.filter {
            arcNames.contains($0.name) || participantNames.contains($0.name) || $0.arc.contains { $0.stage == phase }
        }
        return SourceTimeWindow(phase: phase, characters: characters,
                                events: events.sorted { $0.importance.majorRank > $1.importance.majorRank },
                                worldbuilding: profile.worldbuilding)
    }

    /// 渲染成注入文本：人物卡多行 + 事件列表 + 世界规则，超过 maxChars 截断保留头部。
    public func rendered(maxChars: Int) -> String {
        var lines: [String] = []
        if let phase = phase, !phase.isEmpty {
            lines.append("【原作阶段：\(phase)】")
        }
        if !characters.isEmpty {
            lines.append("【原作人物】")
            for c in characters {
                var card = "◆ \(c.name)"
                if !c.aliases.isEmpty { card += "（\(c.aliases.joined(separator: "/"))）" }
                if let role = c.role, !role.isEmpty { card += "〔\(role)〕" }
                lines.append(card)
                if let oneLine = c.oneLine, !oneLine.isEmpty { lines.append("  定位：\(oneLine)") }
                if let personality = c.personality, !personality.isEmpty { lines.append("  性格：\(personality)") }
                if let abilities = c.abilities, !abilities.isEmpty { lines.append("  能力：\(abilities)") }
                if let appearance = c.appearance, !appearance.isEmpty { lines.append("  外貌：\(appearance)") }
                let relations = c.relationships
                    .filter { !$0.target.isEmpty || !$0.relation.isEmpty }
                    .map { "\($0.target)（\($0.relation)）" }
                if !relations.isEmpty { lines.append("  关系：\(relations.joined(separator: "、"))") }
            }
        }
        if !events.isEmpty {
            lines.append("【该阶段事件】")
            for e in events {
                var line = "◆ \(e.summary)"
                if let phase = e.phase, !phase.isEmpty, phase != self.phase {
                    line += "（\(phase)）"
                }
                if !e.participants.isEmpty { line += "〔\(e.participants.joined(separator: "、"))〕" }
                if let consequence = e.consequence, !consequence.isEmpty {
                    line += " → \(consequence)"
                }
                lines.append(line)
            }
        }
        if !worldbuilding.isEmpty {
            lines.append("【世界设定】")
            for w in worldbuilding.prefix(6) {
                lines.append("- [\(w.category)] \(w.name)：\(w.content)")
            }
        }
        var text = lines.joined(separator: "\n")
        if text.count > maxChars {
            // 预期截断标记长度内保留开头内容，保证总长 ≤ maxChars
            let marker = "……（已截断）"
            let keep = max(0, maxChars - marker.count)
            text = String(text.prefix(keep)) + marker
        }
        return text
    }
}
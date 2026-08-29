import Foundation

/// 文风档案的消费场景（对应设计稿 §4.1 渲染表；eval 为 P2 预留）
public enum StyleCardVariant {
    case writing    // 续写/撰写/润色/扩写
    case outline    // 大纲/批量细纲（P1 启用）
    case antiAI     // 去AI味专项
}

/// 把 StyleProfile 裁剪渲染为注入文本。
/// 各 section 按「风格卡 > 句法/词汇 > 场景 > 对白 > 情绪 > 叙事声音细节」优先级排列，
/// 超预算即停（仿 PromptLibrary.r18Supplement 的贪心装填）。
public enum StyleCardRenderer {

    public static func render(_ profile: StyleProfile, variant: StyleCardVariant) -> String {
        let budget: Int
        switch variant {
        case .writing: budget = PromptLimits.styleProfileCap
        case .outline: budget = PromptLimits.styleProfileOutlineCap
        case .antiAI: budget = PromptLimits.styleProfileAntiAICap
        }

        var sections: [String] = []
        switch variant {
        case .writing:
            sections.append("【文风档案：\(profile.name)】（与上方【风格约束】冲突时，以风格约束为准）")
            if !profile.fingerprintSummary.isEmpty {
                sections.append("风格指纹：\(profile.fingerprintSummary)")
            }
            appendNumberedList("必遵规则", profile.mustRules, into: &sections)
            if let lines = layerLines(profile) { sections.append(lines) }
            appendNumberedList("绝对禁止", profile.avoidRules + profile.antiAI.forbiddenPatterns, into: &sections)
            appendExamples(profile.examples, into: &sections)
        case .outline:
            sections.append("【文风档案：\(profile.name)】")
            if !profile.tags.isEmpty { sections.append("基调：" + profile.tags.joined(separator: "、")) }
            var lines: [String] = []
            if let s = profile.narrativeVoice.pov, !s.isEmpty { lines.append("视角：\(s)") }
            if let s = profile.narrativeVoice.distance, !s.isEmpty { lines.append("叙事距离：\(s)") }
            if let s = profile.sceneRhythm.openings, !s.isEmpty { lines.append("开场习惯：\(s)") }
            if let s = profile.sceneRhythm.closings, !s.isEmpty { lines.append("收束习惯：\(s)") }
            if let s = profile.dialogue.subtextLevel, !s.isEmpty { lines.append("对白：\(s)") }
            if !lines.isEmpty { sections.append(lines.joined(separator: "\n")) }
        case .antiAI:
            sections.append("【文风档案：\(profile.name) · 去AI味专项】")
            appendNumberedList("禁止模式", profile.antiAI.forbiddenPatterns, into: &sections)
            appendNumberedList("自检清单", profile.antiAI.revisionChecks, into: &sections)
            appendNumberedList("该文风禁用套话", profile.diction.bannedMoves, into: &sections)
        }

        var out = ""
        for section in sections {
            let candidate = out.isEmpty ? section : out + "\n" + section
            if candidate.count > budget { break }
            out = candidate
        }
        return out
    }

    // MARK: - 组装辅助

    private static func appendNumberedList(_ title: String, _ items: [String], into sections: inout [String]) {
        let valid = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !valid.isEmpty else { return }
        let numbered = valid.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        sections.append("\(title)：\n\(numbered)")
    }

    private static func appendExamples(_ examples: [StyleExample], into sections: inout [String]) {
        let lines = examples.prefix(3).compactMap { example -> String? in
            guard !example.plain.isEmpty, !example.styled.isEmpty else { return nil }
            return "普通：「\(example.plain)」→ 该文风：「\(example.styled)」"
        }
        guard !lines.isEmpty else { return }
        sections.append("示范对照：\n" + lines.joined(separator: "\n"))
    }

    /// writing variant 的分层机制要点（每层只挑可执行字段，一行一条）
    private static func layerLines(_ p: StyleProfile) -> String? {
        var lines: [String] = []
        let v = p.narrativeVoice
        if let s = v.temperature, !s.isEmpty { lines.append("语气温度：\(s)") }
        if let s = v.distance, !s.isEmpty { lines.append("叙事距离：\(s)") }
        if let s = v.interiority, !s.isEmpty { lines.append("内心戏：\(s)") }
        let syn = p.sentenceSyntax
        if let s = syn.shape, !s.isEmpty { lines.append("主导句型：\(s)") }
        if let s = syn.longShortRatio, !s.isEmpty { lines.append("长短句：\(s)") }
        if let s = syn.punctuationRhythm, !s.isEmpty { lines.append("标点节奏：\(s)") }
        if !syn.signatureMoves.isEmpty { lines.append("招牌句式：" + syn.signatureMoves.joined(separator: "；")) }
        let d = p.diction
        if let s = d.register, !s.isEmpty { lines.append("语域：\(s)") }
        if !d.lexicalFields.isEmpty { lines.append("词汇场：" + d.lexicalFields.joined(separator: "、")) }
        if let s = d.sensoryWeights, !s.isEmpty { lines.append("五感：\(s)") }
        let r = p.sceneRhythm
        if let s = r.actInnerEnvRatio, !s.isEmpty { lines.append("动作/内心/环境：\(s)") }
        if let s = r.transitions, !s.isEmpty { lines.append("转场：\(s)") }
        let dg = p.dialogue
        if let s = dg.lineLength, !s.isEmpty { lines.append("对白密度：\(s)") }
        if let s = dg.tagHabits, !s.isEmpty { lines.append("说话标签：\(s)") }
        let e = p.emotion
        if let s = e.directness, !s.isEmpty { lines.append("情绪处理：\(s)") }
        if !e.preferredCarriers.isEmpty { lines.append("情绪载体：" + e.preferredCarriers.joined(separator: "、")) }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Novel 取卡便捷方法

public extension Novel {
    /// 书绑定的档案（nil = 未启用文风档案）
    func activeStyleProfile(in profiles: [StyleProfile]) -> StyleProfile? {
        guard let id = activeStyleProfileID else { return nil }
        return profiles.first { $0.id == id }
    }

    /// 渲染好的注入文本（未绑定或渲染为空 → nil）
    func styleProfileCard(in profiles: [StyleProfile], variant: StyleCardVariant) -> String? {
        guard let profile = activeStyleProfile(in: profiles) else { return nil }
        let card = StyleCardRenderer.render(profile, variant: variant)
        return card.isEmpty ? nil : card
    }
}

import Foundation

/// Reduce 两段：一段把微摘要按批归并为「阶段摘要」（保留章序/人物状态变化）；
/// 二段把全部阶段摘要 + 已有人物卡归并为最终档案（人物合并去重、弧光保序、事件分 phase）。
public enum SourceReducer {

    /// 一段提示词：输入若干微摘要 JSON 串，输出合并后的阶段摘要（Markdown 文本，< batchChars）
    public static func batchPrompt(micros: [SourceMicroSummarizer.MicroSummary], batchChars: Int) -> String {
        let encoded = micros
            .map { (try? String(data: JSONEncoder().encode($0), encoding: .utf8)) ?? "{}" }
            .joined(separator: "\n---\n")
        return """
        【任务】以下是同一本小说相邻几段正文的微摘要（增量式，共 \(micros.count) 段微摘要）。请合并为一份紧凑的阶段摘要：
        1. 按微摘要出现顺序衔接，保留事件发生顺序与角色状态变化；
        2. 相同角色去重（合并特征、保留最新状态）；相同设定合并；
        3. 输出纯 Markdown 文本（≤ \(batchChars) 字），不要 JSON。
        【微摘要】
        \(encoded)
        """
    }

    /// 二段提示词：输入全部阶段摘要 + 既有档案草稿（人物卡），输出最终档案 JSON
    public static func finalPrompt(stageSummaries: [String],
                                   characters: [CanonCharacter],
                                   styleGuide: String? = nil) -> [LLMMessage] {
        let chars = characters.map { "\($0.name)（\($0.role ?? "")）" }.joined(separator: "、")
        let user = """
        【阶段摘要】
        \(stageSummaries.joined(separator: "\n\n=== 阶段分隔 ===\n\n"))
        【已有的角色名】
        \(chars.isEmpty ? "（空）" : chars)
        【用户笔记】
        \(styleGuide ?? "（无）")

        请生成这本小说的「原作档案」，严格输出 JSON（不要输出其他内容）：
        {"title_suggestion": "根据内容推断的书名（若明确则原文）",
         "characters": [{"name": "", "aliases": ["别名"], "role": "主角/配角/反派…", "oneLine": "一句话定位", "appearance": "", "personality": "", "abilities": "能力体系内描述", "relationships": [{"target": "角色名", "relation": "关系"}], "arc": [{"stage": "原作阶段", "change": "此阶段状态/性格变化"}]}],
         "timeline": [{"phase": "原作阶段", "summary": "事件一句话", "participants": ["角色"], "importance": "major或minor", "consequence": "不可逆事实（无则省略）"}],
         "worldbuilding": [{"category": "地点/势力/规则/物品/力量体系", "name": "", "content": ""}]}
        规则：人物卡合并同一角色（别名归入 aliases）；arc 按阶段先后排列；major 事件至少覆盖每个阶段的标志性转折。
        """
        let system = """
        你是资深网文分析师，负责把全书阶段摘要整理成可供同人创作引用的「原作档案」。
        只提取原作文本确立的事实，不要虚构；同一角色只出一张卡，多阶段变化进 arc。
        """
        return [LLMMessage(role: .system, content: system), LLMMessage(role: .user, content: user)]
    }

    /// 解析二段输出为档案；标题缺失用 fallbackTitle
    public static func parseFinal(_ raw: String, fallbackTitle: String) throws -> SourceNovelProfile {
        guard let json = LLMJSONParser.extractJSONObject(from: raw),
              let data = json.data(using: .utf8) else { throw SourceScanError.parseFailed }
        struct DTO: Codable {
            var title_suggestion: String?
            var characters: [CanonCharacter]?
            var timeline: [CanonEvent]?
            var worldbuilding: [CanonWorldEntry]?
        }
        let dto = try JSONDecoder().decode(DTO.self, from: data)
        let profile = SourceNovelProfile(
            title: dto.title_suggestion?.isEmpty == false ? dto.title_suggestion! : fallbackTitle)
        profile.characters = dto.characters ?? []
        profile.timeline = dto.timeline ?? []
        profile.worldbuilding = dto.worldbuilding ?? []
        return profile
    }
}
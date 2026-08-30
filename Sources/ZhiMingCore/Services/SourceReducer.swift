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
        4. 微摘要中的 foreshadowing（伏笔）：在阶段摘要末尾单列「未回收伏笔」小节——新埋伏笔各一行（◆ 伏笔一句话〔参与角色〕，标注埋设的大致位置），已回收的伏笔一行并标注〔已回收〕；无伏笔则省略该小节。
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

    // MARK: - 续写深度归并

    /// 解析二段输出为档案；标题缺失用 fallbackTitle（普通档案：全书归并）
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

    /// 续写深度归并：输入 1~X 章的阶段摘要（含「未回收伏笔」小节），
    /// 输出续写档案——人物卡含「截至 X 章」现状快照、未回收伏笔清单、剧情弧与走向势能。
    public static func continuationPrompt(stageSummaries: [String], upToChapter: Int) -> [LLMMessage] {
        let user = """
        【阶段摘要】（已分析至第 \(upToChapter) 章）
        \(stageSummaries.joined(separator: "\n\n=== 阶段分隔 ===\n\n"))

        请生成这本小说「截至第 \(upToChapter) 章」的续写档案，严格输出 JSON（不要输出其他内容）：
        {"title_suggestion": "根据内容推断的书名（若明确则原文）",
         "characters": [{"name": "", "aliases": [], "role": "主角/配角/反派…", "oneLine": "一句话定位", "appearance": "", "personality": "", "abilities": "", "current_state": "截至第\(upToChapter)章的现状（等级/能力/装备/心理/关系现状）", "relationships": [{"target": "角色名", "relation": "关系"}], "arc": [{"stage": "原作阶段", "change": "此阶段状态/性格变化"}]}],
         "timeline": [{"phase": "原作阶段", "summary": "事件一句话", "participants": ["角色"], "importance": "major或minor", "consequence": "不可逆事实（无则省略）"}],
         "worldbuilding": [{"category": "地点/势力/规则/物品/力量体系", "name": "", "content": ""}],
         "open_threads": [{"title": "伏笔标题", "detail": "内容与线索（含埋设位置）", "planted_chapter": 埋设章号, "participants": ["角色"]}],
         "plot_arc": "剧情弧与走向势能：主线冲突进展、当前所处阶段、下一阶段的走向势能（一段紧凑叙述）"}
        规则：人物卡以「截至第 \(upToChapter) 章」的最新状态为准，current_state 必填（主要角色）；\
        open_threads 只收录尚未回收的伏笔（以阶段摘要的「未回收伏笔」小节为准，已回收的不收）；不要虚构原文没有的事实。
        """
        let system = """
        你是资深网文分析师，负责把小说前 \(upToChapter) 章的阶段摘要整理成「续写档案」：\
        供后续 AI 从第 \(upToChapter + 1) 章无缝续写。人物现状快照、未回收伏笔、剧情走向势能是核心资产。
        """
        return [LLMMessage(role: .system, content: system), LLMMessage(role: .user, content: user)]
    }

    /// 解析深度归并产物为续写档案（title 缺失用 fallbackTitle）
    public static func parseContinuation(_ raw: String, fallbackTitle: String, upToChapter: Int) throws -> SourceNovelProfile {
        guard let json = LLMJSONParser.extractJSONObject(from: raw),
              let data = json.data(using: .utf8) else { throw SourceScanError.parseFailed }
        struct DTO: Codable {
            var title_suggestion: String?
            var characters: [CanonCharacter]?
            var timeline: [CanonEvent]?
            var worldbuilding: [CanonWorldEntry]?
            var open_threads: [ThreadDTO]?
            var plot_arc: String?
            struct ThreadDTO: Codable {
                var title: String?
                var detail: String?
                var planted_chapter: Int?
                var participants: [String]?
            }
        }
        let dto = try JSONDecoder().decode(DTO.self, from: data)
        let profile = SourceNovelProfile(
            title: dto.title_suggestion?.isEmpty == false ? dto.title_suggestion! : fallbackTitle)
        profile.characters = dto.characters ?? []
        profile.timeline = dto.timeline ?? []
        profile.worldbuilding = dto.worldbuilding ?? []
        profile.continuationFromChapter = upToChapter
        profile.openThreads = (dto.open_threads ?? []).map {
            CanonThread(title: $0.title?.isEmpty == false ? $0.title! : "未命名伏笔",
                        detail: $0.detail ?? "",
                        plantedChapter: $0.planted_chapter,
                        participants: $0.participants ?? [])
        }
        profile.plotArc = dto.plot_arc
        return profile
    }
}
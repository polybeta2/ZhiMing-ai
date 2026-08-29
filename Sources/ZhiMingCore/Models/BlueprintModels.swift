import Foundation

// MARK: - 蓝图结构（字段与 creationFoundation 模板一一对应）

public struct BlueprintCharacter: Codable, Identifiable {
    public var id = UUID()
    public var name: String?
    public var role: String?
    public var appearance: String?
    public var personality: String?
    public var goal: String?

    public enum CodingKeys: String, CodingKey { case name, role, appearance, personality, goal }

    public init(name: String? = nil, role: String? = nil, appearance: String? = nil, personality: String? = nil, goal: String? = nil) {
    self.name = name
    self.role = role
    self.appearance = appearance
    self.personality = personality
    self.goal = goal
    }
}

public struct BlueprintWorld: Codable, Identifiable {
    public var id = UUID()
    public var category: String?
    public var name: String?
    public var content: String?

    public enum CodingKeys: String, CodingKey { case category, name, content }

    public init(category: String? = nil, name: String? = nil, content: String? = nil) {
    self.category = category
    self.name = name
    self.content = content
    }
}

/// 对象数组的元素普遍做「字符串容错」：部分模型（如 gemini-flash 经部分网关）会把
/// 本该是对象数（如 conflict_ladder）的输出成字符串数组，Swift 严格 Codable 因此
/// 整单失败（v2.1.2 修 volumes[0].conflict_ladder[0] typeMismatch）。字符串被当作首字段。
public struct BlueprintSceneCard: Codable {
    public var goal: String?
    public var obstacle: String?
    public var hook: String?

    public enum CodingKeys: String, CodingKey { case goal, obstacle, hook }

    public init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            goal = text; obstacle = nil; hook = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(String.self, forKey: .goal)
        obstacle = try c.decodeIfPresent(String.self, forKey: .obstacle)
        hook = try c.decodeIfPresent(String.self, forKey: .hook)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(goal, forKey: .goal)
        try c.encodeIfPresent(obstacle, forKey: .obstacle)
        try c.encodeIfPresent(hook, forKey: .hook)
    }

    public init(goal: String? = nil, obstacle: String? = nil, hook: String? = nil) {
    self.goal = goal
    self.obstacle = obstacle
    self.hook = hook
    }
}

public struct BlueprintConflictRung: Codable {
    public var level: Int?
    public var obstacle: String?
    public var turning_point: String?

    public enum CodingKeys: String, CodingKey { case level, obstacle, turning_point }

    public init(from decoder: Decoder) throws {
        // 已验证的失稳点：模型把 conflict_ladder 输出成字符串数组时逐项容错为 obstacle
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            level = nil; obstacle = text; turning_point = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decodeIfPresent(Int.self, forKey: .level)
        obstacle = try c.decodeIfPresent(String.self, forKey: .obstacle)
        turning_point = try c.decodeIfPresent(String.self, forKey: .turning_point)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(level, forKey: .level)
        try c.encodeIfPresent(obstacle, forKey: .obstacle)
        try c.encodeIfPresent(turning_point, forKey: .turning_point)
    }

    public init(level: Int? = nil, obstacle: String? = nil, turning_point: String? = nil) {
    self.level = level
    self.obstacle = obstacle
    self.turning_point = turning_point
    }
}

public struct BlueprintInfoGap: Codable {
    public var start: String?
    public var end: String?

    public enum CodingKeys: String, CodingKey { case start, end }

    public init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            start = text; end = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decodeIfPresent(String.self, forKey: .start)
        end = try c.decodeIfPresent(String.self, forKey: .end)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(start, forKey: .start)
        try c.encodeIfPresent(end, forKey: .end)
    }

    public init(start: String? = nil, end: String? = nil) {
    self.start = start
    self.end = end
    }
}

/// 细纲阶段登记的伏笔：埋设章的细纲生成时由 AI 登记，reveal_in 指向计划揭晓章
public struct BlueprintForeshadow: Codable {
    public var title: String?
    public var detail: String?
    public var reveal_in: String?

    public enum CodingKeys: String, CodingKey { case title, detail, reveal_in }

    public init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            title = text; detail = nil; reveal_in = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        reveal_in = try c.decodeIfPresent(String.self, forKey: .reveal_in)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(detail, forKey: .detail)
        try c.encodeIfPresent(reveal_in, forKey: .reveal_in)
    }

    public init(title: String? = nil, detail: String? = nil, reveal_in: String? = nil) {
    self.title = title
    self.detail = detail
    self.reveal_in = reveal_in
    }
}

public struct BlueprintChapter: Codable, Identifiable {
    public var id = UUID()
    public var title: String?
    public var detailed_outline: String?
    public var scene_cards: [BlueprintSceneCard]?
    public var foreshadowings: [BlueprintForeshadow]?

    public enum CodingKeys: String, CodingKey { case title, detailed_outline, scene_cards, foreshadowings }

    public init(title: String? = nil, detailed_outline: String? = nil, scene_cards: [BlueprintSceneCard]? = nil, foreshadowings: [BlueprintForeshadow]? = nil) {
    self.title = title
    self.detailed_outline = detailed_outline
    self.scene_cards = scene_cards
    self.foreshadowings = foreshadowings
    }
}

public struct BlueprintVolume: Codable, Identifiable {
    public var id = UUID()
    public var name: String?
    public var outline: String?
    public var emotion_arc: [String]?
    public var conflict_ladder: [BlueprintConflictRung]?
    public var info_gap: BlueprintInfoGap?
    public var chapters: [BlueprintChapter] = []

    public enum CodingKeys: String, CodingKey {
        case name, outline, emotion_arc, conflict_ladder, info_gap, chapters
    }

    /// 模型偶尔省略空的 chapters 数组：非可选默认字段合成解码缺 key 会抛错，这里显式容错
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        outline = try c.decodeIfPresent(String.self, forKey: .outline)
        emotion_arc = try c.decodeIfPresent([String].self, forKey: .emotion_arc)
        conflict_ladder = try c.decodeIfPresent([BlueprintConflictRung].self, forKey: .conflict_ladder)
        info_gap = try c.decodeIfPresent(BlueprintInfoGap.self, forKey: .info_gap)
        chapters = try c.decodeIfPresent([BlueprintChapter].self, forKey: .chapters) ?? []
    }

    public init(name: String? = nil, outline: String? = nil, emotion_arc: [String]? = nil, conflict_ladder: [BlueprintConflictRung]? = nil, info_gap: BlueprintInfoGap? = nil, chapters: [BlueprintChapter] = []) {
    self.name = name
    self.outline = outline
    self.emotion_arc = emotion_arc
    self.conflict_ladder = conflict_ladder
    self.info_gap = info_gap
    self.chapters = chapters
    }
}

public struct NovelBlueprint: Codable {
    public var title_suggestion: String?
    public var theme: String?
    public var synopsis: String?
    public var perspective: String?
    public var style_guide: String?
    public var characters: [BlueprintCharacter] = []
    public var worldbuilding: [BlueprintWorld] = []
    public var volumes: [BlueprintVolume] = []

    /// 同 BlueprintVolume：characters/worldbuilding/volumes 缺 key 时按空数组容错
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title_suggestion = try c.decodeIfPresent(String.self, forKey: .title_suggestion)
        theme = try c.decodeIfPresent(String.self, forKey: .theme)
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis)
        perspective = try c.decodeIfPresent(String.self, forKey: .perspective)
        style_guide = try c.decodeIfPresent(String.self, forKey: .style_guide)
        characters = try c.decodeIfPresent([BlueprintCharacter].self, forKey: .characters) ?? []
        worldbuilding = try c.decodeIfPresent([BlueprintWorld].self, forKey: .worldbuilding) ?? []
        volumes = try c.decodeIfPresent([BlueprintVolume].self, forKey: .volumes) ?? []
    }

    public init(title_suggestion: String? = nil, theme: String? = nil, synopsis: String? = nil, perspective: String? = nil, style_guide: String? = nil, characters: [BlueprintCharacter] = [], worldbuilding: [BlueprintWorld] = [], volumes: [BlueprintVolume] = []) {
    self.title_suggestion = title_suggestion
    self.theme = theme
    self.synopsis = synopsis
    self.perspective = perspective
    self.style_guide = style_guide
    self.characters = characters
    self.worldbuilding = worldbuilding
    self.volumes = volumes
    }
}

// MARK: - 分阶段结构

/// 澄清提问结果
public struct ClarifyResult: Codable {
    public var enough: Bool?
    public var reason: String?
    public var questions: [String]?

    public init(enough: Bool? = nil, reason: String? = nil, questions: [String]? = nil) {
    self.enough = enough
    self.reason = reason
    self.questions = questions
    }
}

/// 卷章结构提案
public struct StructureProposal: Codable {
    public var concept: String?
    public var volumes: [ProposedVolume] = []

    public struct ProposedVolume: Codable {
        public var name: String?
        public var chapter_count: Int?
    }

    /// volumes 缺 key 容错
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        concept = try c.decodeIfPresent(String.self, forKey: .concept)
        volumes = try c.decodeIfPresent([ProposedVolume].self, forKey: .volumes) ?? []
    }

    public init(concept: String? = nil, volumes: [ProposedVolume] = []) {
    self.concept = concept
    self.volumes = volumes
    }
}

/// 卷纲批次补丁：与 creationVolumeBatch 模板输出契约一一对应
public struct VolumeOutlinePatch: Codable {
    public var name: String?
    public var outline: String?
    public var emotion_arc: [String]?
    public var conflict_ladder: [BlueprintConflictRung]?
    public var info_gap: BlueprintInfoGap?

    public init(name: String? = nil, outline: String? = nil, emotion_arc: [String]? = nil, conflict_ladder: [BlueprintConflictRung]? = nil, info_gap: BlueprintInfoGap? = nil) {
    self.name = name
    self.outline = outline
    self.emotion_arc = emotion_arc
    self.conflict_ladder = conflict_ladder
    self.info_gap = info_gap
    }
}

/// 立项会话快照：退出书籍页/重启后经 SQLite 缓存恢复，AI 上下文与表格不丢失。
/// 只缓存「纯数据」：brief/qaText/proposal/blueprint；自动连续恢复为关闭，
/// 不缓存 in-flight 流（重进后界面处于可继续生成的静止态）。
public struct CreationSessionState: Codable {
    public var phaseRaw: String
    public var brief: String
    public var qaText: String
    public var proposal: StructureProposal?
    public var blueprint: NovelBlueprint?
    public var volumesPerBatch: Int
    public var chaptersPerBatch: Int
    public var autoContinue: Bool

    public init(phaseRaw: String, brief: String, qaText: String, proposal: StructureProposal? = nil, blueprint: NovelBlueprint? = nil, volumesPerBatch: Int, chaptersPerBatch: Int, autoContinue: Bool) {
    self.phaseRaw = phaseRaw
    self.brief = brief
    self.qaText = qaText
    self.proposal = proposal
    self.blueprint = blueprint
    self.volumesPerBatch = volumesPerBatch
    self.chaptersPerBatch = chaptersPerBatch
    self.autoContinue = autoContinue
    }
}

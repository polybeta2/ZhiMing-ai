import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - 宽松集合解码（v2.3 文风蒸馏）
// LLM 常把数组字段写成「甲，乙、丙」式字符串（f41e24a conflict_ladder 同类教训）。
// 本包装器对 数组/字符串/缺失/异型 四种形态全部容错，绝不抛错。
//
// 注意：合成 Codable 对非可选属性在 key 缺失时直接抛 keyNotFound（不使用属性默认值），
// 包装器自身无法拦截缺失键。因此含 @FlexStringArray 字段的结构一律手写 init(from:)，
// 用 decodeIfPresent(FlexStringArray.self) ?? FlexStringArray() 兜底（与 NovelModels
// 的手写 Codable + decodeIfPresent ?? 默认 风格一致）；编码侧交给合成（输出纯数组）。

@propertyWrapper
public struct FlexStringArray: Codable, Equatable {
    public var wrappedValue: [String]

    public init(wrappedValue: [String] = []) { self.wrappedValue = wrappedValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            wrappedValue = array
        } else if let string = try? container.decode(String.self) {
            wrappedValue = Self.splitList(string)
        } else {
            wrappedValue = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }

    /// 中西文常见分隔符统一切分（逗号/顿号/分号/换行）
    public static func splitList(_ raw: String) -> [String] {
        raw.split(whereSeparator: { "，、；;,\n\r".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - 分层机制结构（对应设计稿 §4.1，全部字段可缺失）

public struct StyleNarrativeVoice: Codable, Equatable {
    public var pov: String?
    public var distance: String?
    public var temperature: String?
    public var interiority: String?
    @FlexStringArray public var cameraHabits: [String]

    public init(pov: String? = nil, distance: String? = nil, temperature: String? = nil,
                interiority: String? = nil, cameraHabits: [String] = []) {
        self.pov = pov; self.distance = distance; self.temperature = temperature
        self.interiority = interiority; self.cameraHabits = cameraHabits
    }

    public enum CodingKeys: String, CodingKey {
        case pov, distance, temperature, interiority, cameraHabits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pov = try c.decodeIfPresent(String.self, forKey: .pov)
        distance = try c.decodeIfPresent(String.self, forKey: .distance)
        temperature = try c.decodeIfPresent(String.self, forKey: .temperature)
        interiority = try c.decodeIfPresent(String.self, forKey: .interiority)
        _cameraHabits = try c.decodeIfPresent(FlexStringArray.self, forKey: .cameraHabits) ?? FlexStringArray()
    }
}

public struct StyleSentenceSyntax: Codable, Equatable {
    public var shape: String?
    public var longShortRatio: String?
    public var punctuationRhythm: String?
    public var paragraphCadence: String?
    @FlexStringArray public var signatureMoves: [String]

    public init(shape: String? = nil, longShortRatio: String? = nil, punctuationRhythm: String? = nil,
                paragraphCadence: String? = nil, signatureMoves: [String] = []) {
        self.shape = shape; self.longShortRatio = longShortRatio
        self.punctuationRhythm = punctuationRhythm; self.paragraphCadence = paragraphCadence
        self.signatureMoves = signatureMoves
    }

    public enum CodingKeys: String, CodingKey {
        case shape, longShortRatio, punctuationRhythm, paragraphCadence, signatureMoves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = try c.decodeIfPresent(String.self, forKey: .shape)
        longShortRatio = try c.decodeIfPresent(String.self, forKey: .longShortRatio)
        punctuationRhythm = try c.decodeIfPresent(String.self, forKey: .punctuationRhythm)
        paragraphCadence = try c.decodeIfPresent(String.self, forKey: .paragraphCadence)
        _signatureMoves = try c.decodeIfPresent(FlexStringArray.self, forKey: .signatureMoves) ?? FlexStringArray()
    }
}

public struct StyleDiction: Codable, Equatable {
    public var register: String?
    @FlexStringArray public var lexicalFields: [String]
    @FlexStringArray public var verbHabits: [String]
    @FlexStringArray public var imageSystems: [String]
    public var sensoryWeights: String?
    @FlexStringArray public var bannedMoves: [String]

    public init(register: String? = nil, lexicalFields: [String] = [], verbHabits: [String] = [],
                imageSystems: [String] = [], sensoryWeights: String? = nil, bannedMoves: [String] = []) {
        self.register = register; self.lexicalFields = lexicalFields; self.verbHabits = verbHabits
        self.imageSystems = imageSystems; self.sensoryWeights = sensoryWeights; self.bannedMoves = bannedMoves
    }

    public enum CodingKeys: String, CodingKey {
        case register, lexicalFields, verbHabits, imageSystems, sensoryWeights, bannedMoves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        register = try c.decodeIfPresent(String.self, forKey: .register)
        _lexicalFields = try c.decodeIfPresent(FlexStringArray.self, forKey: .lexicalFields) ?? FlexStringArray()
        _verbHabits = try c.decodeIfPresent(FlexStringArray.self, forKey: .verbHabits) ?? FlexStringArray()
        _imageSystems = try c.decodeIfPresent(FlexStringArray.self, forKey: .imageSystems) ?? FlexStringArray()
        sensoryWeights = try c.decodeIfPresent(String.self, forKey: .sensoryWeights)
        _bannedMoves = try c.decodeIfPresent(FlexStringArray.self, forKey: .bannedMoves) ?? FlexStringArray()
    }
}

public struct StyleSceneRhythm: Codable, Equatable {
    public var openings: String?
    public var closings: String?
    public var actInnerEnvRatio: String?
    public var transitions: String?

    public init(openings: String? = nil, closings: String? = nil,
                actInnerEnvRatio: String? = nil, transitions: String? = nil) {
        self.openings = openings; self.closings = closings
        self.actInnerEnvRatio = actInnerEnvRatio; self.transitions = transitions
    }
    // 全字段可选，合成 Codable 的 decodeIfPresent 天然容忍缺失，无需手写解码。
}

public struct StyleDialogue: Codable, Equatable {
    public var lineLength: String?
    public var subtextLevel: String?
    public var tagHabits: String?
    public var silenceAndGesture: String?

    public init(lineLength: String? = nil, subtextLevel: String? = nil,
                tagHabits: String? = nil, silenceAndGesture: String? = nil) {
        self.lineLength = lineLength; self.subtextLevel = subtextLevel
        self.tagHabits = tagHabits; self.silenceAndGesture = silenceAndGesture
    }
    // 全字段可选，合成 Codable 的 decodeIfPresent 天然容忍缺失，无需手写解码。
}

public struct StyleEmotion: Codable, Equatable {
    public var directness: String?
    @FlexStringArray public var preferredCarriers: [String]
    public var intensityCurve: String?
    @FlexStringArray public var avoidMoves: [String]

    public init(directness: String? = nil, preferredCarriers: [String] = [],
                intensityCurve: String? = nil, avoidMoves: [String] = []) {
        self.directness = directness; self.preferredCarriers = preferredCarriers
        self.intensityCurve = intensityCurve; self.avoidMoves = avoidMoves
    }

    public enum CodingKeys: String, CodingKey {
        case directness, preferredCarriers, intensityCurve, avoidMoves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        directness = try c.decodeIfPresent(String.self, forKey: .directness)
        _preferredCarriers = try c.decodeIfPresent(FlexStringArray.self, forKey: .preferredCarriers) ?? FlexStringArray()
        intensityCurve = try c.decodeIfPresent(String.self, forKey: .intensityCurve)
        _avoidMoves = try c.decodeIfPresent(FlexStringArray.self, forKey: .avoidMoves) ?? FlexStringArray()
    }
}

public struct StyleAntiAI: Codable, Equatable {
    @FlexStringArray public var forbiddenPatterns: [String]
    @FlexStringArray public var revisionChecks: [String]

    public init(forbiddenPatterns: [String] = [], revisionChecks: [String] = []) {
        self.forbiddenPatterns = forbiddenPatterns; self.revisionChecks = revisionChecks
    }

    public enum CodingKeys: String, CodingKey {
        case forbiddenPatterns, revisionChecks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _forbiddenPatterns = try c.decodeIfPresent(FlexStringArray.self, forKey: .forbiddenPatterns) ?? FlexStringArray()
        _revisionChecks = try c.decodeIfPresent(FlexStringArray.self, forKey: .revisionChecks) ?? FlexStringArray()
    }
}

/// 改写示范：styled 必须是新写的示范句，禁止原文摘抄（S4 查重把关）
public struct StyleExample: Codable, Equatable, Identifiable {
    public var id: UUID
    public var plain: String
    public var styled: String
    public var principle: String

    public init(id: UUID = UUID(), plain: String, styled: String, principle: String = "") {
        self.id = id; self.plain = plain; self.styled = styled; self.principle = principle
    }
}

/// 机制观察的短证据（≤ PromptLimits.styleEvidenceCap 字，仅作档案内追溯）
public struct StyleEvidence: Codable, Equatable, Identifiable {
    public var id: UUID
    public var trait: String
    public var snippet: String
    public var confidence: String

    public init(id: UUID = UUID(), trait: String, snippet: String, confidence: String = "medium") {
        self.id = id; self.trait = trait; self.snippet = snippet; self.confidence = confidence
    }
}

/// 本地计量快照（StyleMetrics.compute 的产物，随档案保存供比对）
public struct StyleMetricsSnapshot: Codable, Equatable {
    public var sampleCharCount: Int
    public var sentenceCount: Int
    public var medianSentenceLength: Double
    public var shortSentenceRatio: Double      // ≤10 字句子占比
    public var longSentenceRatio: Double       // ≥25 字句子占比
    public var alternationRate: Double         // 相邻句长短类别变化率
    public var dialogueLineRatio: Double       // 含引号行占比
    public var dashPer1k: Double               // 「——」每千字
    public var ellipsisPer1k: Double           // 「……」每千字
    public var exclamationPer1k: Double        // 「！!」每千字
    public var questionPer1k: Double           // 「？?」每千字

    public init(sampleCharCount: Int = 0, sentenceCount: Int = 0, medianSentenceLength: Double = 0,
                shortSentenceRatio: Double = 0, longSentenceRatio: Double = 0, alternationRate: Double = 0,
                dialogueLineRatio: Double = 0, dashPer1k: Double = 0, ellipsisPer1k: Double = 0,
                exclamationPer1k: Double = 0, questionPer1k: Double = 0) {
        self.sampleCharCount = sampleCharCount; self.sentenceCount = sentenceCount
        self.medianSentenceLength = medianSentenceLength; self.shortSentenceRatio = shortSentenceRatio
        self.longSentenceRatio = longSentenceRatio; self.alternationRate = alternationRate
        self.dialogueLineRatio = dialogueLineRatio; self.dashPer1k = dashPer1k
        self.ellipsisPer1k = ellipsisPer1k; self.exclamationPer1k = exclamationPer1k
        self.questionPer1k = questionPer1k
    }
}

/// 用户修正记录（P1 增量蒸馏用，P0 仅建模不写入）
public struct StyleCorrection: Codable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var layer: String
    public var field: String
    public var before: String
    public var after: String
    public var reason: String

    public init(id: UUID = UUID(), date: Date = .now, layer: String, field: String,
                before: String, after: String, reason: String) {
        self.id = id; self.date = date; self.layer = layer; self.field = field
        self.before = before; self.after = after; self.reason = reason
    }
}

// MARK: - 文风档案（全局风格库条目）

/// 只描述语言层机制，不含内容层信息（情节/人物/设定明确排除）
public final class StyleProfile: Identifiable, ObservableObject, Codable {
    public let id: UUID
    @Published public var name: String
    @Published public var createdAt: Date
    @Published public var updatedAt: Date
    @Published public var sourceNote: String
    @Published public var sampleCharCount: Int
    /// high / medium / low（样本不足或查重有丢弃时降级）
    @Published public var confidence: String

    // —— 风格卡（人读视图 + 轻量注入来源）——
    @Published public var tags: [String]
    @Published public var fingerprintSummary: String
    @Published public var mustRules: [String]
    @Published public var avoidRules: [String]

    // —— 分层机制 ——
    @Published public var narrativeVoice: StyleNarrativeVoice
    @Published public var sentenceSyntax: StyleSentenceSyntax
    @Published public var diction: StyleDiction
    @Published public var sceneRhythm: StyleSceneRhythm
    @Published public var dialogue: StyleDialogue
    @Published public var emotion: StyleEmotion
    @Published public var antiAI: StyleAntiAI

    // —— 示例与证据 ——
    @Published public var examples: [StyleExample]
    @Published public var evidence: [StyleEvidence]
    @Published public var localMetrics: StyleMetricsSnapshot?
    @Published public var corrections: [StyleCorrection]

    public init(id: UUID = UUID(), name: String, sourceNote: String = "",
                sampleCharCount: Int = 0, confidence: String = "medium") {
        self.id = id
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.sourceNote = sourceNote
        self.sampleCharCount = sampleCharCount
        self.confidence = confidence
        self.tags = []
        self.fingerprintSummary = ""
        self.mustRules = []
        self.avoidRules = []
        self.narrativeVoice = StyleNarrativeVoice()
        self.sentenceSyntax = StyleSentenceSyntax()
        self.diction = StyleDiction()
        self.sceneRhythm = StyleSceneRhythm()
        self.dialogue = StyleDialogue()
        self.emotion = StyleEmotion()
        self.antiAI = StyleAntiAI()
        self.examples = []
        self.evidence = []
        self.localMetrics = nil
        self.corrections = []
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, sourceNote, sampleCharCount, confidence
        case tags, fingerprintSummary, mustRules, avoidRules
        case narrativeVoice, sentenceSyntax, diction, sceneRhythm, dialogue, emotion, antiAI
        case examples, evidence, localMetrics, corrections
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        sourceNote = try c.decodeIfPresent(String.self, forKey: .sourceNote) ?? ""
        sampleCharCount = try c.decodeIfPresent(Int.self, forKey: .sampleCharCount) ?? 0
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence) ?? "medium"
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        fingerprintSummary = try c.decodeIfPresent(String.self, forKey: .fingerprintSummary) ?? ""
        mustRules = try c.decodeIfPresent([String].self, forKey: .mustRules) ?? []
        avoidRules = try c.decodeIfPresent([String].self, forKey: .avoidRules) ?? []
        narrativeVoice = try c.decodeIfPresent(StyleNarrativeVoice.self, forKey: .narrativeVoice) ?? StyleNarrativeVoice()
        sentenceSyntax = try c.decodeIfPresent(StyleSentenceSyntax.self, forKey: .sentenceSyntax) ?? StyleSentenceSyntax()
        diction = try c.decodeIfPresent(StyleDiction.self, forKey: .diction) ?? StyleDiction()
        sceneRhythm = try c.decodeIfPresent(StyleSceneRhythm.self, forKey: .sceneRhythm) ?? StyleSceneRhythm()
        dialogue = try c.decodeIfPresent(StyleDialogue.self, forKey: .dialogue) ?? StyleDialogue()
        emotion = try c.decodeIfPresent(StyleEmotion.self, forKey: .emotion) ?? StyleEmotion()
        antiAI = try c.decodeIfPresent(StyleAntiAI.self, forKey: .antiAI) ?? StyleAntiAI()
        examples = try c.decodeIfPresent([StyleExample].self, forKey: .examples) ?? []
        evidence = try c.decodeIfPresent([StyleEvidence].self, forKey: .evidence) ?? []
        localMetrics = try c.decodeIfPresent(StyleMetricsSnapshot.self, forKey: .localMetrics)
        corrections = try c.decodeIfPresent([StyleCorrection].self, forKey: .corrections) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(sourceNote, forKey: .sourceNote)
        try c.encode(sampleCharCount, forKey: .sampleCharCount)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(tags, forKey: .tags)
        try c.encode(fingerprintSummary, forKey: .fingerprintSummary)
        try c.encode(mustRules, forKey: .mustRules)
        try c.encode(avoidRules, forKey: .avoidRules)
        try c.encode(narrativeVoice, forKey: .narrativeVoice)
        try c.encode(sentenceSyntax, forKey: .sentenceSyntax)
        try c.encode(diction, forKey: .diction)
        try c.encode(sceneRhythm, forKey: .sceneRhythm)
        try c.encode(dialogue, forKey: .dialogue)
        try c.encode(emotion, forKey: .emotion)
        try c.encode(antiAI, forKey: .antiAI)
        try c.encode(examples, forKey: .examples)
        try c.encode(evidence, forKey: .evidence)
        try c.encodeIfPresent(localMetrics, forKey: .localMetrics)
        try c.encode(corrections, forKey: .corrections)
    }
}

import Foundation

// MARK: - 蒸馏事件（VM 据此驱动阶段显示与流式进度）

public enum StyleDistillPhase: Equatable {
    case measuring      // S1 本地计量（瞬时，仍发事件保序）
    case analyzing      // S2 机制分析（LLM）
    case buildingCard   // S3 风格卡与示例（LLM）
    case checking       // S4 查重校验（本地 + 可能的修正请求）
}

public enum StyleDistillEvent {
    case phase(StyleDistillPhase)
    case stream(StreamEvent)          // 透传 LLM 流式事件供进度可视化
    /// S2 原始输出上抛（会话缓存用：VM 收到后落盘，失败/中断可恢复）
    case analysisReady(String)
    case completed(StyleProfile)
}

public enum StyleDistillError: LocalizedError {
    case emptySource
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptySource: return "样本文本为空，无法蒸馏"
        case .parseFailed(let stage): return "\(stage) JSON 解析失败，请重试或更换模型"
        }
    }
}

// MARK: - LLM 宽松 DTO（snake_case 对应提示词字段；全部可缺失）

struct StyleAnalysisDraft: Decodable {
    var narrative_voice: Voice?
    var sentence_syntax: Syntax?
    var diction: Diction?
    var scene_rhythm: Rhythm?
    var dialogue: Dialogue?
    var emotion: Emotion?
    var anti_ai: AntiAI?
    var evidence: [Evidence]?

    struct Voice: Decodable { var pov: String?; var distance: String?; var temperature: String?; var interiority: String?; var camera_habits: FlexStringArray? }
    struct Syntax: Decodable { var shape: String?; var long_short_ratio: String?; var punctuation_rhythm: String?; var paragraph_cadence: String?; var signature_moves: FlexStringArray? }
    struct Diction: Decodable { var register: String?; var lexical_fields: FlexStringArray?; var verb_habits: FlexStringArray?; var image_systems: FlexStringArray?; var sensory_weights: String?; var banned_moves: FlexStringArray? }
    struct Rhythm: Decodable { var openings: String?; var closings: String?; var act_inner_env_ratio: String?; var transitions: String? }
    struct Dialogue: Decodable { var line_length: String?; var subtext_level: String?; var tag_habits: String?; var silence_and_gesture: String? }
    struct Emotion: Decodable { var directness: String?; var preferred_carriers: FlexStringArray?; var intensity_curve: String?; var avoid_moves: FlexStringArray? }
    struct AntiAI: Decodable { var forbidden_patterns: FlexStringArray?; var revision_checks: FlexStringArray? }
    struct Evidence: Decodable { var trait: String?; var snippet: String?; var confidence: String? }

    func apply(to profile: StyleProfile) {
        if let v = narrative_voice {
            profile.narrativeVoice.pov = v.pov
            profile.narrativeVoice.distance = v.distance
            profile.narrativeVoice.temperature = v.temperature
            profile.narrativeVoice.interiority = v.interiority
            profile.narrativeVoice.cameraHabits = v.camera_habits?.wrappedValue ?? []
        }
        if let s = sentence_syntax {
            profile.sentenceSyntax.shape = s.shape
            profile.sentenceSyntax.longShortRatio = s.long_short_ratio
            profile.sentenceSyntax.punctuationRhythm = s.punctuation_rhythm
            profile.sentenceSyntax.paragraphCadence = s.paragraph_cadence
            profile.sentenceSyntax.signatureMoves = s.signature_moves?.wrappedValue ?? []
        }
        if let d = diction {
            profile.diction.register = d.register
            profile.diction.lexicalFields = d.lexical_fields?.wrappedValue ?? []
            profile.diction.verbHabits = d.verb_habits?.wrappedValue ?? []
            profile.diction.imageSystems = d.image_systems?.wrappedValue ?? []
            profile.diction.sensoryWeights = d.sensory_weights
            profile.diction.bannedMoves = d.banned_moves?.wrappedValue ?? []
        }
        if let r = scene_rhythm {
            profile.sceneRhythm.openings = r.openings
            profile.sceneRhythm.closings = r.closings
            profile.sceneRhythm.actInnerEnvRatio = r.act_inner_env_ratio
            profile.sceneRhythm.transitions = r.transitions
        }
        if let d = dialogue {
            profile.dialogue.lineLength = d.line_length
            profile.dialogue.subtextLevel = d.subtext_level
            profile.dialogue.tagHabits = d.tag_habits
            profile.dialogue.silenceAndGesture = d.silence_and_gesture
        }
        if let e = emotion {
            profile.emotion.directness = e.directness
            profile.emotion.preferredCarriers = e.preferred_carriers?.wrappedValue ?? []
            profile.emotion.intensityCurve = e.intensity_curve
            profile.emotion.avoidMoves = e.avoid_moves?.wrappedValue ?? []
        }
        if let a = anti_ai {
            profile.antiAI.forbiddenPatterns = a.forbidden_patterns?.wrappedValue ?? []
            profile.antiAI.revisionChecks = a.revision_checks?.wrappedValue ?? []
        }
        profile.evidence = (evidence ?? []).compactMap { item in
            guard let trait = item.trait?.trimmingCharacters(in: .whitespacesAndNewlines), !trait.isEmpty else { return nil }
            return StyleEvidence(trait: trait,
                                 snippet: String((item.snippet ?? "").prefix(PromptLimits.styleEvidenceCap)),
                                 confidence: item.confidence ?? "medium")
        }
    }
}

struct StyleCardDraft: Decodable {
    var name: String?
    var tags: FlexStringArray?
    var fingerprint_summary: String?
    var must_rules: FlexStringArray?
    var avoid_rules: FlexStringArray?
    var examples: [Example]?

    struct Example: Decodable { var plain: String?; var styled: String?; var principle: String? }

    func apply(to profile: StyleProfile) {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            profile.name = String(name.prefix(20))
        }
        profile.tags = tags?.wrappedValue ?? profile.tags
        if let summary = fingerprint_summary { profile.fingerprintSummary = summary }
        profile.mustRules = must_rules?.wrappedValue ?? profile.mustRules
        profile.avoidRules = avoid_rules?.wrappedValue ?? profile.avoidRules
        profile.examples = (examples ?? []).compactMap { item in
            guard let styled = item.styled?.trimmingCharacters(in: .whitespacesAndNewlines), !styled.isEmpty else { return nil }
            return StyleExample(plain: (item.plain ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                                styled: styled,
                                principle: (item.principle ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

struct StyleFixItem: Decodable {
    var index: Int
    var styled: String
    var principle: String?
}

// MARK: - 蒸馏流水线

/// S1 计量（本地）→ S2 机制分析（LLM）→ S3 风格卡（LLM）→ S4 查重（本地 + 可选修正请求）。
/// 纯逻辑无 UI 依赖：LLMClient 注入，Linux XCTest 全流程可测。
public final class StyleDistillationService {
    private let client: LLMClient
    private let config: GenerationConfig

    public init(client: LLMClient, config: GenerationConfig) {
        self.client = client
        self.config = config
    }

    public func events(sourceText: String, sourceNote: String,
                       analyzeSystem: String, cardSystem: String, fixSystem: String,
                       cachedAnalysisRaw: String? = nil) -> AsyncThrowingStream<StyleDistillEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // S1 本地计量 + 分段采样
                    continuation.yield(.phase(.measuring))
                    let metrics = StyleMetrics.compute(sourceText)
                    let samples = StyleMetrics.sampleSegments(in: sourceText, maxChars: PromptLimits.styleSampleCap)
                    guard !samples.isEmpty else { throw StyleDistillError.emptySource }

                    let profile = StyleProfile(name: sourceNote.isEmpty ? "未命名文风" : String(sourceNote.prefix(20)),
                                               sourceNote: sourceNote,
                                               sampleCharCount: sourceText.count)
                    profile.localMetrics = metrics

                    // S2 机制分析：命中可用缓存则跳过 LLM 调用（中断/失败恢复路径）
                    if let analysis = cachedAnalysisRaw.flatMap({ LLMJSONParser.decode(StyleAnalysisDraft.self, fromJSONObjectIn: $0) }) {
                        analysis.apply(to: profile)
                        continuation.yield(.phase(.buildingCard))
                    } else {
                        continuation.yield(.phase(.analyzing))
                        let analysisRaw = try await complete(messages(analyzeSystem, analysisUser(samples, metrics)))
                        guard let analysis = LLMJSONParser.decode(StyleAnalysisDraft.self, fromJSONObjectIn: analysisRaw) else {
                            throw StyleDistillError.parseFailed("机制分析")
                        }
                        analysis.apply(to: profile)
                        continuation.yield(.analysisReady(analysisRaw))
                        continuation.yield(.phase(.buildingCard))
                    }

                    // S3 风格卡与示例
                    let cardRaw = try await complete(messages(cardSystem, cardUser(profile)))
                    guard let card = LLMJSONParser.decode(StyleCardDraft.self, fromJSONObjectIn: cardRaw) else {
                        throw StyleDistillError.parseFailed("风格卡")
                    }
                    card.apply(to: profile)

                    // S4 查重校验
                    continuation.yield(.phase(.checking))
                    try await checkAndFix(profile: profile, sourceText: sourceText, fixSystem: fixSystem)

                    continuation.yield(.completed(profile))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: 消息装配

    private func messages(_ system: String, _ user: String) -> [LLMMessage] {
        [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    private func analysisUser(_ samples: [StyleMetrics.Sample], _ metrics: StyleMetricsSnapshot) -> String {
        var parts = samples.map { "【样本·\($0.label)】\n\($0.text)" }
        parts.append("""
        【计量数据】
        - 样本字数：\(metrics.sampleCharCount)；句子数：\(metrics.sentenceCount)
        - 句长中位数：\(Int(metrics.medianSentenceLength)) 字；短句(≤10字)占比 \(Int(metrics.shortSentenceRatio * 100))%；长句(≥25字)占比 \(Int(metrics.longSentenceRatio * 100))%
        - 相邻句长短变化率：\(Int(metrics.alternationRate * 100))%；含引号对话行占比 \(Int(metrics.dialogueLineRatio * 100))%
        - 每千字：破折号 \(String(format: "%.1f", metrics.dashPer1k))、省略号 \(String(format: "%.1f", metrics.ellipsisPer1k))、叹号 \(String(format: "%.1f", metrics.exclamationPer1k))、问号 \(String(format: "%.1f", metrics.questionPer1k))
        """)
        return parts.joined(separator: "\n\n")
    }

    private func cardUser(_ profile: StyleProfile) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let analysisJSON = (try? encoder.encode(profile))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "【机制分析结果】\n\(analysisJSON)\n\n请按系统要求输出风格卡 JSON。"
    }

    // MARK: LLM 调用（聚合 content 流）

    private func complete(_ messages: [LLMMessage]) async throws -> String {
        var accumulated = ""
        for try await event in client.streamChat(messages: messages, config: config) {
            if case .content(let delta) = event { accumulated += delta }
        }
        return accumulated
    }

    // MARK: S4 查重与修正

    private func checkAndFix(profile: StyleProfile, sourceText: String, fixSystem: String) async throws {
        func violatedExamples() -> [(index: Int, example: StyleExample)] {
            profile.examples.enumerated()
                .filter { StyleMetrics.hasViolation($0.element.styled, against: sourceText) }
                .map { (index: $0.offset, example: $0.element) }
        }
        // 证据片段违规直接剔除（修正成本高于收益），不作 LLM 回炉
        profile.evidence.removeAll { StyleMetrics.hasViolation($0.snippet, against: sourceText) }

        let violations = violatedExamples()
        guard !violations.isEmpty else { return }

        // 一次修正请求：回传违规示范重写
        let list = violations.map { "\($0.index). styled：\($0.example.styled)" }.joined(separator: "\n")
        let raw = try await complete(messages(fixSystem, "【违规示范】\n\(list)"))
        if let items = LLMJSONParser.decode([StyleFixItem].self, fromJSONObjectIn: raw) {
            for item in items where item.index >= 0 && item.index < profile.examples.count {
                if !StyleMetrics.hasViolation(item.styled, against: sourceText) {
                    profile.examples[item.index].styled = item.styled
                    if let principle = item.principle?.trimmingCharacters(in: .whitespacesAndNewlines), !principle.isEmpty {
                        profile.examples[item.index].principle = principle
                    }
                }
            }
        }
        // 仍违规的示范直接丢弃；确有丢弃才降置信度
        let stillViolated = violatedExamples()
        for (index, _) in stillViolated.reversed() {
            profile.examples.remove(at: index)
        }
        if !stillViolated.isEmpty { profile.confidence = "low" }
    }
}

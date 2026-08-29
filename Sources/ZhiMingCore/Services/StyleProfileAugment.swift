import Foundation

/// 增量蒸馏合并：用新样本蒸馏出的档案更新旧档案。
/// 层字段：新值非空且与旧值不同 → 覆盖并记录 corrections（L9 修正日志）；
/// 集合字段（tags/mustRules/avoidRules/载体/禁语等）：并集去重（保留旧顺序，新值追加在后）；
/// 样本域数据（examples/evidence/localMetrics）：整体替换为新样本的产物；
/// sourceNote/name 保留原值（档案身份不变）。
public enum StyleProfileAugment {

    /// 修正日志上限：超出时淘汰最旧记录，防止长期追加把档案撑爆
    public static let maxCorrections = 50

    public static func merge(existing: StyleProfile, fresh: StyleProfile, reason: String) {
        var corrections: [StyleCorrection] = []

        func overwrite(_ field: String, old: String?, new: String?) {
            let oldValue = old?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let newValue = new?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !newValue.isEmpty, newValue != oldValue else { return }
            corrections.append(StyleCorrection(layer: "augment", field: field,
                                               before: oldValue, after: newValue, reason: reason))
        }

        // —— 分层机制（逐字段覆盖 + 记录）——
        overwrite("narrativeVoice.pov", old: existing.narrativeVoice.pov, new: fresh.narrativeVoice.pov)
        existing.narrativeVoice.pov = pick(existing.narrativeVoice.pov, fresh.narrativeVoice.pov)
        overwrite("narrativeVoice.distance", old: existing.narrativeVoice.distance, new: fresh.narrativeVoice.distance)
        existing.narrativeVoice.distance = pick(existing.narrativeVoice.distance, fresh.narrativeVoice.distance)
        overwrite("narrativeVoice.temperature", old: existing.narrativeVoice.temperature, new: fresh.narrativeVoice.temperature)
        existing.narrativeVoice.temperature = pick(existing.narrativeVoice.temperature, fresh.narrativeVoice.temperature)
        overwrite("narrativeVoice.interiority", old: existing.narrativeVoice.interiority, new: fresh.narrativeVoice.interiority)
        existing.narrativeVoice.interiority = pick(existing.narrativeVoice.interiority, fresh.narrativeVoice.interiority)
        existing.narrativeVoice.cameraHabits = union(old: existing.narrativeVoice.cameraHabits, new: fresh.narrativeVoice.cameraHabits)

        overwrite("sentenceSyntax.shape", old: existing.sentenceSyntax.shape, new: fresh.sentenceSyntax.shape)
        existing.sentenceSyntax.shape = pick(existing.sentenceSyntax.shape, fresh.sentenceSyntax.shape)
        overwrite("sentenceSyntax.longShortRatio", old: existing.sentenceSyntax.longShortRatio, new: fresh.sentenceSyntax.longShortRatio)
        existing.sentenceSyntax.longShortRatio = pick(existing.sentenceSyntax.longShortRatio, fresh.sentenceSyntax.longShortRatio)
        overwrite("sentenceSyntax.punctuationRhythm", old: existing.sentenceSyntax.punctuationRhythm, new: fresh.sentenceSyntax.punctuationRhythm)
        existing.sentenceSyntax.punctuationRhythm = pick(existing.sentenceSyntax.punctuationRhythm, fresh.sentenceSyntax.punctuationRhythm)
        overwrite("sentenceSyntax.paragraphCadence", old: existing.sentenceSyntax.paragraphCadence, new: fresh.sentenceSyntax.paragraphCadence)
        existing.sentenceSyntax.paragraphCadence = pick(existing.sentenceSyntax.paragraphCadence, fresh.sentenceSyntax.paragraphCadence)
        existing.sentenceSyntax.signatureMoves = union(old: existing.sentenceSyntax.signatureMoves, new: fresh.sentenceSyntax.signatureMoves)

        overwrite("diction.register", old: existing.diction.register, new: fresh.diction.register)
        existing.diction.register = pick(existing.diction.register, fresh.diction.register)
        overwrite("diction.sensoryWeights", old: existing.diction.sensoryWeights, new: fresh.diction.sensoryWeights)
        existing.diction.sensoryWeights = pick(existing.diction.sensoryWeights, fresh.diction.sensoryWeights)
        existing.diction.lexicalFields = union(old: existing.diction.lexicalFields, new: fresh.diction.lexicalFields)
        existing.diction.verbHabits = union(old: existing.diction.verbHabits, new: fresh.diction.verbHabits)
        existing.diction.imageSystems = union(old: existing.diction.imageSystems, new: fresh.diction.imageSystems)
        existing.diction.bannedMoves = union(old: existing.diction.bannedMoves, new: fresh.diction.bannedMoves)

        overwrite("sceneRhythm.openings", old: existing.sceneRhythm.openings, new: fresh.sceneRhythm.openings)
        existing.sceneRhythm.openings = pick(existing.sceneRhythm.openings, fresh.sceneRhythm.openings)
        overwrite("sceneRhythm.closings", old: existing.sceneRhythm.closings, new: fresh.sceneRhythm.closings)
        existing.sceneRhythm.closings = pick(existing.sceneRhythm.closings, fresh.sceneRhythm.closings)
        overwrite("sceneRhythm.actInnerEnvRatio", old: existing.sceneRhythm.actInnerEnvRatio, new: fresh.sceneRhythm.actInnerEnvRatio)
        existing.sceneRhythm.actInnerEnvRatio = pick(existing.sceneRhythm.actInnerEnvRatio, fresh.sceneRhythm.actInnerEnvRatio)
        overwrite("sceneRhythm.transitions", old: existing.sceneRhythm.transitions, new: fresh.sceneRhythm.transitions)
        existing.sceneRhythm.transitions = pick(existing.sceneRhythm.transitions, fresh.sceneRhythm.transitions)

        overwrite("dialogue.lineLength", old: existing.dialogue.lineLength, new: fresh.dialogue.lineLength)
        existing.dialogue.lineLength = pick(existing.dialogue.lineLength, fresh.dialogue.lineLength)
        overwrite("dialogue.subtextLevel", old: existing.dialogue.subtextLevel, new: fresh.dialogue.subtextLevel)
        existing.dialogue.subtextLevel = pick(existing.dialogue.subtextLevel, fresh.dialogue.subtextLevel)
        overwrite("dialogue.tagHabits", old: existing.dialogue.tagHabits, new: fresh.dialogue.tagHabits)
        existing.dialogue.tagHabits = pick(existing.dialogue.tagHabits, fresh.dialogue.tagHabits)
        overwrite("dialogue.silenceAndGesture", old: existing.dialogue.silenceAndGesture, new: fresh.dialogue.silenceAndGesture)
        existing.dialogue.silenceAndGesture = pick(existing.dialogue.silenceAndGesture, fresh.dialogue.silenceAndGesture)

        overwrite("emotion.directness", old: existing.emotion.directness, new: fresh.emotion.directness)
        existing.emotion.directness = pick(existing.emotion.directness, fresh.emotion.directness)
        overwrite("emotion.intensityCurve", old: existing.emotion.intensityCurve, new: fresh.emotion.intensityCurve)
        existing.emotion.intensityCurve = pick(existing.emotion.intensityCurve, fresh.emotion.intensityCurve)
        existing.emotion.preferredCarriers = union(old: existing.emotion.preferredCarriers, new: fresh.emotion.preferredCarriers)
        existing.emotion.avoidMoves = union(old: existing.emotion.avoidMoves, new: fresh.emotion.avoidMoves)
        existing.antiAI.forbiddenPatterns = union(old: existing.antiAI.forbiddenPatterns, new: fresh.antiAI.forbiddenPatterns)
        existing.antiAI.revisionChecks = union(old: existing.antiAI.revisionChecks, new: fresh.antiAI.revisionChecks)

        // —— 风格卡 ——
        overwrite("fingerprintSummary", old: existing.fingerprintSummary, new: fresh.fingerprintSummary)
        if !fresh.fingerprintSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existing.fingerprintSummary = fresh.fingerprintSummary
        }
        existing.tags = union(old: existing.tags, new: fresh.tags, cap: 8)
        existing.mustRules = union(old: existing.mustRules, new: fresh.mustRules, cap: 15)
        existing.avoidRules = union(old: existing.avoidRules, new: fresh.avoidRules, cap: 8)

        // —— 样本域数据：整体替换 ——
        existing.examples = fresh.examples
        existing.evidence = fresh.evidence
        existing.localMetrics = fresh.localMetrics
        existing.sampleCharCount += fresh.sampleCharCount

        // —— 修正日志：旧记录在前、新记录在后；超限淘汰最旧（头部）——
        var merged = existing.corrections
        merged.append(contentsOf: corrections)
        if merged.count > maxCorrections {
            merged = Array(merged.suffix(maxCorrections))
        }
        existing.corrections = merged
    }

    /// 新值非空取新值，否则保留旧值（记录日志的判定与取值共用此语义）
    private static func pick(_ old: String?, _ new: String?) -> String? {
        let trimmed = new?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? old : new
    }

    /// 并集去重：保留旧顺序，新值追加在后；cap 为 0 表示不限
    private static func union(old: [String], new: [String], cap: Int = 0) -> [String] {
        var seen = Set(old.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        var merged = old
        for item in new {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            merged.append(trimmed)
        }
        guard cap > 0, merged.count > cap else { return merged }
        return Array(merged.prefix(cap))
    }
}

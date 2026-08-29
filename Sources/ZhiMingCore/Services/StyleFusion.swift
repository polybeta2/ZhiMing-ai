import Foundation

/// 多档案按层融合（novel-style-skills 的 fusion 思路）：
/// 叙事声音/句法/词汇/场景节奏/对白/情绪 六层各选一个来源档案，
/// 反AI 禁令与禁语取全体并集，标签/规则取并集，示范对照与指纹小结取基底档案。
/// 产出全新 id 的档案（confidence 标 low：合成档案需使用者自行校验）。
public enum StyleFusion {

    /// 每层的来源档案 id
    public struct LayerChoices: Codable, Equatable {
        public var voice: UUID
        public var syntax: UUID
        public var diction: UUID
        public var rhythm: UUID
        public var dialogue: UUID
        public var emotion: UUID

        public init(voice: UUID, syntax: UUID, diction: UUID,
                    rhythm: UUID, dialogue: UUID, emotion: UUID) {
            self.voice = voice
            self.syntax = syntax
            self.diction = diction
            self.rhythm = rhythm
            self.dialogue = dialogue
            self.emotion = emotion
        }
    }

    /// 参与融合的档案不足、choices 指向未知档案、或 base 不在 participants 中时返回 nil
    public static func fuse(name: String, base: StyleProfile,
                            participants: [StyleProfile], choices: LayerChoices) -> StyleProfile? {
        guard participants.count >= 1,
              participants.contains(where: { $0.id == base.id }) else { return nil }
        func source(_ id: UUID) -> StyleProfile? {
            participants.first { $0.id == id }
        }
        guard let voice = source(choices.voice),
              let syntax = source(choices.syntax),
              let diction = source(choices.diction),
              let rhythm = source(choices.rhythm),
              let dialogue = source(choices.dialogue),
              let emotion = source(choices.emotion) else { return nil }

        let fused = StyleProfile(name: String(name.prefix(20)), sourceNote: "融合自 \(participants.count) 份档案")
        fused.confidence = "low"
        fused.fingerprintSummary = base.fingerprintSummary
        fused.tags = union(participants.map(\.tags), cap: 8)
        fused.mustRules = union(participants.map(\.mustRules), cap: 15)
        fused.avoidRules = union(participants.map(\.avoidRules), cap: 8)
        fused.examples = base.examples

        fused.narrativeVoice = voice.narrativeVoice
        fused.sentenceSyntax = syntax.sentenceSyntax
        fused.diction = diction.diction
        fused.sceneRhythm = rhythm.sceneRhythm
        fused.dialogue = dialogue.dialogue
        fused.emotion = emotion.emotion

        fused.antiAI.forbiddenPatterns = union(participants.map { $0.antiAI.forbiddenPatterns })
        fused.antiAI.revisionChecks = union(participants.map { $0.antiAI.revisionChecks })
        fused.diction.bannedMoves = union(participants.map { $0.diction.bannedMoves })

        return fused
    }

    /// 多列表并集去重：按档案顺序拼接，保持出现顺序；cap 为 0 表示不限
    private static func union(_ lists: [[String]], cap: Int = 0) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for list in lists {
            for item in list {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
                seen.insert(trimmed)
                merged.append(trimmed)
            }
        }
        guard cap > 0, merged.count > cap else { return merged }
        return Array(merged.prefix(cap))
    }
}

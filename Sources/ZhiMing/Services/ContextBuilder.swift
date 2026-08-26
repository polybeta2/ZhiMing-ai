import Foundation

struct BuiltContext {
    let rendered: String
    let truncatedSections: [String]      // 被预算裁掉的段落名，用于界面提示
}

/// 三级上下文装配（司命 context_orchestrator 的简化版）：
/// 必需层（不参与预算裁剪）：风格约束、本章细纲、正文末尾 800 字
/// 高优先层：最近 3 章摘要 + 关键事实
/// 可选层（超预算时先裁）：场景角色卡（≤12）、世界观条目（≤8）
enum ContextBuilder {
    static let tailLength = 800
    static let maxSceneCharacters = 12
    static let maxWorldEntries = 8

    /// 必需层兜底截断：用户可无限编辑的字段（风格约束/梗概/卷纲/细纲等）超限时保留尾部，
    /// 并记入 truncatedSections 在界面提示（尾部更贴近当前写作进度，故留尾不留头）。
    private static func cappedRequired(_ text: String,
                                       label: String,
                                       limit: Int = PromptLimits.requiredFieldCap,
                                       truncated: inout [String]) -> String {
        guard text.count > limit else { return text }
        truncated.append("\(label)（超过 \(limit) 字，已截断保留末尾）")
        return "……" + String(text.suffix(limit))
    }

    static func buildContinueContext(chapter: Chapter, novel: Novel, budgetChars: Int) -> BuiltContext {
        var required: [String] = []
        var high: [(String, String)] = []
        var optional: [(String, String)] = []
        var truncated: [String] = []

        if let style = novel.styleGuide, !style.isEmpty {
            required.append("【风格约束】\n"
                + cappedRequired(style, label: "风格约束", truncated: &truncated))
        }
        if let outline = chapter.detailedOutline, !outline.isEmpty {
            required.append("【本章细纲】\n"
                + cappedRequired(outline, label: "本章细纲", truncated: &truncated))
        }
        // 场景卡：比细纲更细的执行粒度，随细纲同入必需层
        if let cards = chapter.sceneCards, !cards.isEmpty {
            let rendered = renderSceneCards(cards)
            required.append("【场景卡】\n"
                + cappedRequired(rendered, label: "场景卡", truncated: &truncated))
        }

        let previous = previousSummaries(of: chapter, in: novel, limit: 3)
        if !previous.isEmpty {
            let text = previous.map { "第\($0.0)章：\($0.1)" }.joined(separator: "\n")
            high.append(("前文摘要", "【前文摘要（最近 \(previous.count) 章）】\n\(text)"))
        }
        let facts = recentKeyFacts(of: chapter, in: novel, limit: 3)
        if !facts.isEmpty {
            high.append(("关键事实", "【关键事实】\n" + facts.map { "- \($0)" }.joined(separator: "\n")))
        }

        let sceneChars = novel.characters
            .filter(\.isSceneRelevant)
            .prefix(maxSceneCharacters)
            .map(renderCharacter)
        if !sceneChars.isEmpty {
            optional.append(("角色状态", "【角色当前状态】\n" + sceneChars.joined(separator: "\n\n")))
        }
        let world = novel.worldEntries.prefix(maxWorldEntries).map {
            "- [\($0.category)] \($0.name)：\($0.content)"
        }
        if !world.isEmpty {
            optional.append(("世界观", "【世界观条目】\n" + world.joined(separator: "\n")))
        }

        var used = required.joined(separator: "\n\n").count
        var accepted: [String] = []

        for (name, text) in high + optional {
            if used + text.count <= budgetChars {
                accepted.append(text)
                used += text.count
            } else {
                truncated.append(name)
            }
        }

        var tail = chapter.content
        if tail.count > tailLength { tail = String(tail.suffix(tailLength)) }
        let parts = required + accepted + ["【正文末尾】\n\(tail.isEmpty ? "（本章尚无正文，请从开头写起）" : tail)"]
        return BuiltContext(rendered: parts.joined(separator: "\n\n"), truncatedSections: truncated)
    }

    private static func previousSummaries(of chapter: Chapter, in novel: Novel, limit: Int) -> [(Int, String)] {
        summaries(before: novel.globalIndex(of: chapter), in: novel, limit: limit)
    }

    private static func recentKeyFacts(of chapter: Chapter, in novel: Novel, limit: Int) -> [String] {
        keyFacts(before: novel.globalIndex(of: chapter), in: novel, limit: limit)
    }

    /// 锚点之前的最近摘要（锚点=目标章全局序；卷场景传其最早章序或全书末尾）
    private static func summaries(before globalIndex: Int, in novel: Novel, limit: Int) -> [(Int, String)] {
        novel.allChaptersInOrder
            .filter { ($0.summary != nil) && novel.globalIndex(of: $0) < globalIndex }
            .suffix(limit)
            .map { (novel.globalIndex(of: $0), $0.summary!.summaryText) }
    }

    private static func keyFacts(before globalIndex: Int, in novel: Novel, limit: Int) -> [String] {
        novel.allChaptersInOrder
            .filter { ($0.summary != nil) && novel.globalIndex(of: $0) < globalIndex }
            .suffix(limit)
            .flatMap { $0.summary!.keyFacts }
    }

    private static func renderCharacter(_ c: CharacterCard) -> String {
        var lines = ["◆ \(c.name)" + (c.aliases.isEmpty ? "" : "（\(c.aliases.joined(separator: "/"))）")]
        if let v = c.personality, !v.isEmpty { lines.append("性格：\(v)") }
        if let v = c.currentGoal, !v.isEmpty { lines.append("当前目标：\(v)") }
        if let v = c.currentLocation, !v.isEmpty { lines.append("当前位置：\(v)") }
        if let v = c.physicalState, !v.isEmpty { lines.append("身体状态：\(v)") }
        if let v = c.mentalState, !v.isEmpty { lines.append("心理状态：\(v)") }
        if let v = c.lastSeenChapterTitle, !v.isEmpty { lines.append("最近出场：\(v)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 大纲辅助装配（卷纲 / 章细纲）

/// 大纲生成的目标对象
enum OutlineTarget {
    case volume(Volume)
    case chapter(Chapter)
}

extension ContextBuilder {

    /// 大纲上下文三级装配：
    /// 必需层：梗概/风格 + 目标现状（卷信息 或 所在卷/相邻章/本章现状）
    /// 高优先层：前文摘要、关键事实、最近正文节选（增强：对齐已写走向，防细纲与成稿脱节）
    /// 可选层：全书结构（卷纲用）、场景角色卡（细纲用）
    static func buildOutlineContext(target: OutlineTarget, novel: Novel, budgetChars: Int) -> BuiltContext {
        var required: [String] = []
        var high: [(String, String)] = []
        var optional: [(String, String)] = []
        var truncated: [String] = []

        // 锚点：卷取其最早章的全局序（尚无章节则视为全书末尾），章取自身序
        let anchorIndex: Int
        switch target {
        case .volume(let volume):
            let indices = volume.chapters.map { novel.globalIndex(of: $0) }.filter { $0 > 0 }
            anchorIndex = indices.min() ?? novel.allChaptersInOrder.count + 1
        case .chapter(let chapter):
            anchorIndex = novel.globalIndex(of: chapter)
        }

        if !novel.synopsis.isEmpty {
            required.append("【作品梗概】\n"
                + cappedRequired(novel.synopsis, label: "作品梗概", truncated: &truncated))
        }
        if let style = novel.styleGuide, !style.isEmpty {
            required.append("【风格约束】\n"
                + cappedRequired(style, label: "风格约束", truncated: &truncated))
        }

        let previous = summaries(before: anchorIndex, in: novel, limit: 3)
        if !previous.isEmpty {
            high.append(("前文摘要", "【前文摘要（最近 \(previous.count) 章）】\n"
                + previous.map { "第\($0.0)章：\($0.1)" }.joined(separator: "\n")))
        }
        let facts = keyFacts(before: anchorIndex, in: novel, limit: 3)
        if !facts.isEmpty {
            high.append(("关键事实", "【关键事实】\n" + facts.map { "- \($0)" }.joined(separator: "\n")))
        }
        if let prose = recentProseTail(in: novel, excluding: anchorChapterID(of: target), limit: 600) {
            high.append(("最近正文节选", "【最近正文节选】\n\(prose)"))
        }

        switch target {
        case .volume(let volume):
            required.append(volumeBrief(volume, truncated: &truncated))
            optional.append(("全书结构", "【全书结构】\n" + structureText(novel: novel, highlight: volume)))
        case .chapter(let chapter):
            required.append(contentsOf: chapterBrief(chapter, novel: novel, truncated: &truncated))
            let sceneChars = novel.characters
                .filter(\.isSceneRelevant)
                .prefix(maxSceneCharacters)
                .map(renderCharacter)
            if !sceneChars.isEmpty {
                optional.append(("角色状态", "【角色当前状态】\n" + sceneChars.joined(separator: "\n\n")))
            }
        }

        // 预算裁剪（与 buildContinueContext 同规则：必需层不参与）
        var used = required.joined(separator: "\n\n").count
        var accepted: [String] = []
        for (name, text) in high + optional {
            if used + text.count <= budgetChars {
                accepted.append(text)
                used += text.count
            } else {
                truncated.append(name)
            }
        }
        return BuiltContext(rendered: (required + accepted).joined(separator: "\n\n"),
                            truncatedSections: truncated)
    }

    private static func anchorChapterID(of target: OutlineTarget) -> UUID? {
        if case .chapter(let chapter) = target { return chapter.id }
        return nil
    }

    /// 场景卡渲染（续写必需层与细纲上下文共用）
    static func renderSceneCards(_ cards: [SceneCard]) -> String {
        cards.enumerated().map { index, card in
            var parts: [String] = []
            if !card.goal.isEmpty { parts.append("目标：\(card.goal)") }
            if !card.obstacle.isEmpty { parts.append("阻力：\(card.obstacle)") }
            if !card.hook.isEmpty { parts.append("钩子：\(card.hook)") }
            return "卡\(index + 1)：" + (parts.isEmpty ? "（空）" : parts.joined(separator: "；"))
        }.joined(separator: "\n")
    }

    private static func volumeBrief(_ volume: Volume, truncated: inout [String]) -> String {
        var lines = ["【本卷信息】", "卷名：\(volume.name)"]
        if let outline = volume.outline, !outline.isEmpty {
            lines.append("当前卷纲（在其基础上修订，而非推倒重来）：\n"
                + cappedRequired(outline, label: "当前卷纲", truncated: &truncated))
        }
        // 四维现状一并给出，便于 AI 修订时保持维度连续
        if let arc = volume.emotionArc, !arc.isEmpty {
            lines.append("情绪走向：" + arc.joined(separator: " → "))
        }
        if let ladder = volume.conflictLadder?.sorted(by: { $0.level < $1.level }), !ladder.isEmpty {
            lines.append("冲突阶梯：")
            for rung in ladder {
                var line = "  L\(rung.level) 阻力：\(rung.obstacle)"
                if let tp = rung.turningPoint, !tp.isEmpty { line += "（转折：\(tp)）" }
                lines.append(line)
            }
        }
        if let gap = volume.infoGap, !gap.isEmpty {
            lines.append("信息差：起点=\(gap.start)；终点=\(gap.end)")
        }
        let titles = volume.sortedChapters.map(\.title)
        if !titles.isEmpty {
            lines.append("本卷已有章节：\(titles.joined(separator: "、"))")
        }
        return lines.joined(separator: "\n")
    }

    private static func structureText(novel: Novel, highlight: Volume?) -> String {
        novel.sortedVolumes.map { volume -> String in
            let mark = volume.id == highlight?.id ? "▶（本卷）" : ""
            let titles = volume.sortedChapters.map(\.title).joined(separator: "、")
            return titles.isEmpty ? "◇ \(volume.name)\(mark)" : "◇ \(volume.name)\(mark)：\(titles)"
        }.joined(separator: "\n")
    }

    private static func chapterBrief(_ chapter: Chapter, novel: Novel, truncated: inout [String]) -> [String] {
        var blocks: [String] = []

        if let volume = chapter.volume {
            var lines = ["【所在卷】", "卷名：\(volume.name)"]
            if let outline = volume.outline, !outline.isEmpty {
                lines.append("卷纲：\n" + cappedRequired(outline, label: "所在卷卷纲", truncated: &truncated))
            }
            blocks.append(lines.joined(separator: "\n"))
        }

        let all = novel.allChaptersInOrder
        if let index = all.firstIndex(where: { $0.id == chapter.id }) {
            if index > 0 {
                blocks.append("【上一章】\n" + neighborLine(all[index - 1]))
            }
            if index + 1 < all.count {
                blocks.append("【下一章】\n" + neighborLine(all[index + 1]))
            }
        }

        var current = ["【本章现状】", "章题：\(chapter.title)"]
        if let outline = chapter.detailedOutline, !outline.isEmpty {
            current.append("当前细纲（在其基础上修订，而非推倒重来）：\n"
                + cappedRequired(outline, label: "当前细纲", truncated: &truncated))
        }
        if let cards = chapter.sceneCards, !cards.isEmpty {
            current.append("场景卡：\n" + renderSceneCards(cards))
        }
        if !chapter.content.isEmpty {
            var tail = chapter.content
            if tail.count > tailLength { tail = String(tail.suffix(tailLength)) }
            current.append("本章已写正文末尾：\n\(tail)")
        }
        blocks.append(current.joined(separator: "\n"))
        return blocks
    }

    private static func neighborLine(_ chapter: Chapter) -> String {
        var line = "\(chapter.title)："
        if let outline = chapter.detailedOutline, !outline.isEmpty {
            line += outline.count > 120 ? String(outline.prefix(120)) + "……" : outline
        } else if !chapter.content.isEmpty {
            line += "（已开写，暂无细纲）"
        } else {
            line += "（未填写）"
        }
        return line
    }

    /// 最近实际写作走向：最后更新且非空的章节末尾（排除目标章自身，避免与本章现状重复）
    private static func recentProseTail(in novel: Novel, excluding: UUID?, limit: Int) -> String? {
        let written = novel.allChaptersInOrder.filter { !$0.content.isEmpty && $0.id != excluding }
        guard let latest = written.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
        var tail = latest.content
        if tail.count > limit { tail = String(tail.suffix(limit)) }
        return "《\(latest.title)》末尾：\n\(tail)"
    }

    /// 写作助手参考上下文：让助手“读懂设定”——角色状态/世界观/叙事账本/全书结构 + 最近实际走向。
    /// 无必需层（梗概与风格由 writingAssistantSystem 单独注入，避免重复），全部参与预算裁剪。
    static func buildAssistantContext(novel: Novel, budgetChars: Int) -> BuiltContext {
        var high: [(String, String)] = []
        var optional: [(String, String)] = []

        // 锚点取全书末尾：助手应了解截至当前的全部已建档信息
        let anchorIndex = novel.allChaptersInOrder.count + 1

        let previous = summaries(before: anchorIndex, in: novel, limit: 3)
        if !previous.isEmpty {
            high.append(("前文摘要", "【前文摘要（最近 \(previous.count) 章）】\n"
                + previous.map { "第\($0.0)章：\($0.1)" }.joined(separator: "\n")))
        }
        let facts = keyFacts(before: anchorIndex, in: novel, limit: 3)
        if !facts.isEmpty {
            high.append(("关键事实", "【关键事实】\n" + facts.map { "- \($0)" }.joined(separator: "\n")))
        }
        if let prose = recentProseTail(in: novel, excluding: nil, limit: 600) {
            high.append(("最近正文节选", "【最近正文节选】\n\(prose)"))
        }

        let sceneChars = novel.characters
            .filter(\.isSceneRelevant)
            .prefix(maxSceneCharacters)
            .map(renderCharacter)
        if !sceneChars.isEmpty {
            optional.append(("角色状态", "【角色当前状态】\n" + sceneChars.joined(separator: "\n\n")))
        }
        let world = novel.worldEntries.prefix(maxWorldEntries).map {
            "- [\($0.category)] \($0.name)：\($0.content)"
        }
        if !world.isEmpty {
            optional.append(("世界观", "【世界观条目】\n" + world.joined(separator: "\n")))
        }
        if !novel.volumes.isEmpty {
            optional.append(("全书结构", "【全书结构】\n" + structureText(novel: novel, highlight: nil)))
        }

        // 预算裁剪（高优先层先于可选层）
        var truncated: [String] = []
        var used = 0
        var accepted: [String] = []
        for (name, text) in high + optional {
            if used + text.count <= budgetChars {
                accepted.append(text)
                used += text.count
            } else {
                truncated.append(name)
            }
        }
        return BuiltContext(rendered: accepted.joined(separator: "\n\n"),
                            truncatedSections: truncated)
    }
}

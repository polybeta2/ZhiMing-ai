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

    static func buildContinueContext(chapter: Chapter, novel: Novel, budgetChars: Int) -> BuiltContext {
        var required: [String] = []
        var high: [(String, String)] = []
        var optional: [(String, String)] = []

        if let style = novel.styleGuide, !style.isEmpty {
            required.append("【风格约束】\n\(style)")
        }
        if let outline = chapter.detailedOutline, !outline.isEmpty {
            required.append("【本章细纲】\n\(outline)")
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

        var truncated: [String] = []
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
        let all = novel.allChaptersInOrder
            .filter { ($0.summary != nil) && novel.globalIndex(of: $0) < novel.globalIndex(of: chapter) }
            .suffix(limit)
        return all.map { (novel.globalIndex(of: $0), $0.summary!.summaryText) }
    }

    private static func recentKeyFacts(of chapter: Chapter, in novel: Novel, limit: Int) -> [String] {
        let all = novel.allChaptersInOrder
            .filter { ($0.summary != nil) && novel.globalIndex(of: $0) < novel.globalIndex(of: chapter) }
            .suffix(limit)
        return all.flatMap { $0.summary!.keyFacts }
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

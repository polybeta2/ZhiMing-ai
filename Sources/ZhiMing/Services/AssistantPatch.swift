import Foundation

/// 写作助手访问模式：只读 = 仅建议；读写 = 可提议补丁，经用户确认后写入设定。
enum AssistantAccessMode: String {
    case readOnly = "只读"
    case readWrite = "读写"
}

/// 写作助手「读写模式」的设定补丁协议：
/// 模型在回复末尾输出 ```zm-patch 围栏 JSON，本类型负责提取/描述/应用。
/// 模型本身没有直接写权——apply(to:store:) 只会由用户在确认卡上点「应用」触发。
/// 范围：角色增改、世界观增改、梗概/视角/风格更新、卷/章重命名、章节场景卡增删改；
/// 仍不支持删除角色/世界观/卷/章本体。
struct AssistantPatch: Codable {
    struct CharacterUpdate: Codable {
        let find: String
        let set: [String: String]
    }

    struct CharacterAdd: Codable {
        let name: String
        var aliases: [String]?
        var appearance: String?
        var personality: String?
        var background: String?
        var currentGoal: String?
        var currentLocation: String?
        var physicalState: String?
        var mentalState: String?
    }

    struct WorldUpsert: Codable {
        var category: String?
        var name: String
        var content: String
    }

    struct NovelUpdates: Codable {
        var synopsis: String?
        var perspective: String?
        var styleGuide: String?
    }

    /// 重命名指令（卷/章共用）：find=现有名称（卷支持「第N卷」），to=新名称
    struct NameRename: Codable {
        var find: String
        var to: String
    }

    /// 场景卡字段 DTO：全可选，便于模型省略空字段
    struct SceneCardDTO: Codable {
        var index: Int?
        var goal: String?
        var obstacle: String?
        var hook: String?

        /// 转换为实体卡；三字段全空视为无效
        var asCard: SceneCard? {
            let g = (goal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let o = (obstacle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let h = (hook ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if g.isEmpty && o.isEmpty && h.isEmpty { return nil }
            return SceneCard(goal: g, obstacle: o, hook: h)
        }
    }

    /// 单章场景卡操作组：replace 与 update/add/remove 互斥（replace 优先）
    struct SceneCardsOp: Codable {
        var chapter: String
        var replace: [SceneCardDTO]?
        var update: [SceneCardDTO]?
        var add: [SceneCardDTO]?
        var remove: [Int]?
    }

    var summary: String?
    var character_updates: [CharacterUpdate]?
    var character_adds: [CharacterAdd]?
    var world_upserts: [WorldUpsert]?
    var novel_updates: NovelUpdates?
    var volume_renames: [NameRename]?
    var chapter_renames: [NameRename]?
    var scene_cards: [SceneCardsOp]?

    // MARK: - 提取

    /// 从回复中提取补丁：优先找能解码成功的围栏块，兜底取全文首个 {…} 对象。
    /// 返回剥离补丁后的展示文本（供聊天气泡显示，不含裸 JSON）。
    static func extract(in text: String) -> (patch: AssistantPatch?, cleanedText: String) {
        guard let range = patchFenceRange(in: text) ?? jsonFallbackRange(in: text),
              let patch = decode(String(text[range])),
              !isEmptyPatch(patch) else {
            return (nil, text)
        }
        var cleaned = text
        cleaned.replaceSubrange(range, with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return (patch, cleaned)
    }

    /// 只有包含至少一项实际变更的对象才算补丁，避免把普通 JSON 回复误判
    private static func isEmptyPatch(_ patch: AssistantPatch) -> Bool {
        (patch.character_updates?.isEmpty ?? true)
            && (patch.character_adds?.isEmpty ?? true)
            && (patch.world_upserts?.isEmpty ?? true)
            && patch.novel_updates == nil
            && (patch.volume_renames?.isEmpty ?? true)
            && (patch.chapter_renames?.isEmpty ?? true)
            && (patch.scene_cards?.isEmpty ?? true)
    }

    /// 扫描 ``` 围栏：跳过语言标记行后能解码为补丁的第一个块
    private static func patchFenceRange(in text: String) -> Range<String.Index>? {
        var cursor = text.startIndex
        while let open = text.range(of: "```", range: cursor..<text.endIndex) {
            guard let close = text.range(of: "```", range: open.upperBound..<text.endIndex) else { return nil }
            let inner = text[open.upperBound..<close.lowerBound]
            let payload: Substring
            if let newline = inner.firstIndex(of: "\n") {
                payload = inner[inner.index(after: newline)...]
            } else {
                payload = inner
            }
            if let patch = decode(String(payload)), !isEmptyPatch(patch) {
                return open.lowerBound..<close.upperBound
            }
            cursor = close.upperBound
        }
        return nil
    }

    private static func jsonFallbackRange(in text: String) -> Range<String.Index>? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return nil }
        return start..<text.index(after: end)
    }

    private static func decode(_ source: String) -> AssistantPatch? {
        guard let data = source.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AssistantPatch.self, from: data)
    }

    // MARK: - 定位

    /// 角色定位：精确名/别名 → 双向包含匹配
    static func matchCharacter(_ query: String, in novel: Novel) -> CharacterCard? {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return nil }
        if let exact = novel.characters.first(where: { $0.name == keyword || $0.aliases.contains(keyword) }) {
            return exact
        }
        return novel.characters.first { $0.name.contains(keyword) || keyword.contains($0.name) }
    }

    /// 卷定位：精确名 → 「第N卷」序号 → 双向包含
    static func matchVolume(_ query: String, in novel: Novel) -> Volume? {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return nil }
        if let exact = novel.volumes.first(where: { $0.name == keyword }) { return exact }
        if let order = volumeNumber(in: keyword),
           let byOrder = novel.sortedVolumes.first(where: { $0.sortOrder == order }) {
            return byOrder
        }
        return novel.volumes.first { $0.name.contains(keyword) || keyword.contains($0.name) }
    }

    /// 解析「第N卷」中的 N
    private static func volumeNumber(in text: String) -> Int? {
        guard let open = text.range(of: "第"),
              let close = text.range(of: "卷", range: open.upperBound..<text.endIndex) else { return nil }
        let digits = text[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
        return Int(digits)
    }

    /// 章定位：支持「卷名/章题」消歧 → 全书精确题名 → 双向包含
    static func matchChapter(_ query: String, in novel: Novel) -> Chapter? {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return nil }

        let candidates: [Chapter]
        var titleKey = keyword
        if keyword.contains("/") {
            let parts = keyword.split(separator: "/", maxSplits: 1).map(String.init)
            let volumeKey = parts[0].trimmingCharacters(in: .whitespaces)
            titleKey = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            candidates = matchVolume(volumeKey, in: novel)?.sortedChapters ?? novel.allChaptersInOrder
        } else {
            candidates = novel.allChaptersInOrder
        }
        if let exact = candidates.first(where: { $0.title == titleKey }) { return exact }
        return candidates.first { $0.title.contains(titleKey) || titleKey.contains($0.title) }
    }

    // MARK: - 变更清单（确认卡展示）

    /// 人可读的拟议变更行；找不到目标的条目也会列出并标注将跳过
    func describe(novel: Novel) -> [String] {
        var lines: [String] = []
        for update in character_updates ?? [] {
            if let target = Self.matchCharacter(update.find, in: novel) {
                let keys = update.set.keys.sorted().joined(separator: "、")
                lines.append("角色「\(target.name)」更新：\(keys)")
            } else {
                lines.append("⚠️ 未找到角色「\(update.find)」（应用时将跳过）")
            }
        }
        for add in character_adds ?? [] {
            let name = add.name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { lines.append("新增角色「\(name)」") }
        }
        for upsert in world_upserts ?? [] {
            let name = upsert.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let exists = novel.worldEntries.contains { $0.name == name }
            lines.append("\(exists ? "更新" : "新增")世界观「\(name)」")
        }
        for rename in volume_renames ?? [] {
            let to = rename.to.trimmingCharacters(in: .whitespaces)
            guard !to.isEmpty else { continue }
            if let target = Self.matchVolume(rename.find, in: novel) {
                lines.append("卷「\(target.name)」重命名为「\(to)」")
            } else {
                lines.append("⚠️ 未找到卷「\(rename.find)」（应用时将跳过）")
            }
        }
        for rename in chapter_renames ?? [] {
            let to = rename.to.trimmingCharacters(in: .whitespaces)
            guard !to.isEmpty else { continue }
            if let target = Self.matchChapter(rename.find, in: novel) {
                lines.append("章节「\(target.title)」重命名为「\(to)」")
            } else {
                lines.append("⚠️ 未找到章节「\(rename.find)」（应用时将跳过）")
            }
        }
        for op in scene_cards ?? [] {
            guard let chapter = Self.matchChapter(op.chapter, in: novel) else {
                lines.append("⚠️ 未找到章节「\(op.chapter)」（场景卡变更将跳过）")
                continue
            }
            var parts: [String] = []
            if !(op.replace ?? []).isEmpty { parts.append("整组替换 \((op.replace ?? []).count) 张") }
            if let updates = op.update, !updates.isEmpty { parts.append("更新 \(updates.count) 处") }
            if let adds = op.add, !adds.isEmpty { parts.append("新增 \(adds.count) 张") }
            if let removes = op.remove, !removes.isEmpty { parts.append("删除 \(removes.count) 张") }
            if !parts.isEmpty {
                lines.append("《\(chapter.title)》场景卡：\(parts.joined(separator: "、"))")
            }
        }
        if let updates = novel_updates {
            if let value = updates.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                lines.append("更新作品梗概")
            }
            if let value = updates.perspective?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                lines.append("更新叙事视角")
            }
            if let value = updates.styleGuide?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                lines.append("更新风格约束")
            }
        }
        return lines
    }

    // MARK: - 应用

    /// 写入数据层并保存；返回逐条结果（含跳过原因）供界面提示。
    @MainActor
    func apply(to novel: Novel, store: AppStore) -> [String] {
        var results: [String] = []

        for update in character_updates ?? [] {
            guard let target = Self.matchCharacter(update.find, in: novel) else {
                results.append("⚠️ 未找到角色「\(update.find)」，已跳过")
                continue
            }
            var changed: [String] = []
            for (field, value) in update.set {
                if Self.apply(field: field, value: value, to: target) {
                    changed.append(field)
                }
            }
            results.append(changed.isEmpty
                ? "⚠️ 角色「\(target.name)」无可识别字段"
                : "✅ 角色「\(target.name)」：\(changed.sorted().joined(separator: "、"))")
        }

        for add in character_adds ?? [] {
            let name = add.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let card = CharacterCard(name: name)
            card.aliases = add.aliases ?? []
            card.appearance = add.appearance
            card.personality = add.personality
            card.background = add.background
            card.currentGoal = add.currentGoal
            card.currentLocation = add.currentLocation
            card.physicalState = add.physicalState
            card.mentalState = add.mentalState
            card.novel = novel
            novel.characters.append(card)
            results.append("✅ 新增角色「\(name)」")
        }

        for upsert in world_upserts ?? [] {
            let name = upsert.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            if let existing = novel.worldEntries.first(where: { $0.name == name }) {
                existing.content = upsert.content
                results.append("✅ 更新世界观「\(name)」")
            } else {
                let validCategories = Set(WorldListView.categories)
                let category = validCategories.contains(upsert.category ?? "") ? upsert.category! : "其他"
                let entry = WorldEntry(category: category, name: name, content: upsert.content)
                entry.novel = novel
                novel.worldEntries.append(entry)
                results.append("✅ 新增世界观「\(name)」")
            }
        }

        for rename in volume_renames ?? [] {
            let to = rename.to.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !to.isEmpty else { continue }
            guard let target = Self.matchVolume(rename.find, in: novel) else {
                results.append("⚠️ 未找到卷「\(rename.find)」，已跳过")
                continue
            }
            let old = target.name
            target.name = to
            results.append("✅ 卷「\(old)」→「\(to)」")
        }

        for rename in chapter_renames ?? [] {
            let to = rename.to.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !to.isEmpty else { continue }
            guard let target = Self.matchChapter(rename.find, in: novel) else {
                results.append("⚠️ 未找到章节「\(rename.find)」，已跳过")
                continue
            }
            let old = target.title
            target.title = to
            results.append("✅ 章节「\(old)」→「\(to)」")
        }

        for op in scene_cards ?? [] {
            guard let chapter = Self.matchChapter(op.chapter, in: novel) else {
                results.append("⚠️ 未找到章节「\(op.chapter)」，场景卡变更已跳过")
                continue
            }
            var cards = chapter.sceneCards ?? []
            var actions: [String] = []

            if let replace = op.replace, !replace.isEmpty {
                cards = replace.compactMap(\.asCard)
                actions.append("整组替换为 \(cards.count) 张")
            } else {
                if let updates = op.update, !updates.isEmpty {
                    var touched = 0
                    for dto in updates {
                        guard let index = dto.index, cards.indices.contains(index - 1) else { continue }
                        var card = cards[index - 1]
                        if let g = dto.goal?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty { card.goal = g }
                        if let o = dto.obstacle?.trimmingCharacters(in: .whitespacesAndNewlines), !o.isEmpty { card.obstacle = o }
                        if let hk = dto.hook?.trimmingCharacters(in: .whitespacesAndNewlines), !hk.isEmpty { card.hook = hk }
                        cards[index - 1] = card
                        touched += 1
                    }
                    if touched > 0 { actions.append("更新 \(touched) 处") }
                }
                if let removes = op.remove, !removes.isEmpty {
                    let valid = removes.filter { cards.indices.contains($0 - 1) }.sorted(by: >)
                    for index in valid { cards.remove(at: index - 1) }
                    if !valid.isEmpty { actions.append("删除 \(valid.count) 张") }
                }
                if let adds = op.add, !adds.isEmpty {
                    let newCards = adds.compactMap(\.asCard)
                    cards += newCards
                    if !newCards.isEmpty { actions.append("新增 \(newCards.count) 张") }
                }
            }

            chapter.sceneCards = cards.isEmpty ? nil : cards
            results.append(actions.isEmpty
                ? "⚠️ 《\(chapter.title)》场景卡无可执行变更"
                : "✅ 《\(chapter.title)》场景卡：\(actions.joined(separator: "、"))")
        }

        if let updates = novel_updates {
            if let value = updates.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                novel.synopsis = value
                results.append("✅ 更新作品梗概")
            }
            if let value = updates.perspective?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                novel.perspective = value
                results.append("✅ 更新叙事视角")
            }
            if let value = updates.styleGuide?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                novel.styleGuide = value
                results.append("✅ 更新风格约束")
            }
        }

        store.save()
        return results
    }

    /// 字段白名单：仅这些键会被写入，其余静默忽略并在结果中体现
    private static func apply(field: String, value: String, to card: CharacterCard) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        switch field {
        case "name": card.name = trimmed
        case "aliases":
            card.aliases = trimmed
                .split(whereSeparator: { ",，、".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        case "appearance": card.appearance = trimmed
        case "personality": card.personality = trimmed
        case "background": card.background = trimmed
        case "currentGoal": card.currentGoal = trimmed
        case "currentLocation": card.currentLocation = trimmed
        case "physicalState": card.physicalState = trimmed
        case "mentalState": card.mentalState = trimmed
        case "isSceneRelevant": card.isSceneRelevant = (trimmed as NSString).boolValue
        default: return false
        }
        return true
    }
}

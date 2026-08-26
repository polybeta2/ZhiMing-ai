import Foundation

/// 写作助手访问模式：只读 = 仅建议；读写 = 可提议补丁，经用户确认后写入设定。
enum AssistantAccessMode: String {
    case readOnly = "只读"
    case readWrite = "读写"
}

/// 写作助手「读写模式」的设定补丁协议：
/// 模型在回复末尾输出 ```zm-patch 围栏 JSON，本类型负责提取/描述/应用。
/// 模型本身没有直接写权——apply(to:store:) 只会由用户在确认卡上点「应用」触发。
/// v1 范围：角色增改、世界观增改、梗概/视角/风格更新；不支持删除操作。
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

    var summary: String?
    var character_updates: [CharacterUpdate]?
    var character_adds: [CharacterAdd]?
    var world_upserts: [WorldUpsert]?
    var novel_updates: NovelUpdates?

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

    // MARK: - 变更清单（确认卡展示）

    /// 人可读的拟议变更行；找不到目标角色的条目也会列出并标注将跳过
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

    /// 角色定位：精确名/别名 → 双向包含匹配
    static func matchCharacter(_ query: String, in novel: Novel) -> CharacterCard? {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return nil }
        if let exact = novel.characters.first(where: { $0.name == keyword || $0.aliases.contains(keyword) }) {
            return exact
        }
        return novel.characters.first { $0.name.contains(keyword) || keyword.contains($0.name) }
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

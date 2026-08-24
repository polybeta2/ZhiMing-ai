import Foundation

/// 4 套提示词模板（分节结构借鉴司命 chapter-quality.md）
enum PromptTemplates {
    static func continueWriting(context: BuiltContext, wordTarget: Int, extra: String?) -> [LLMMessage] {
        let system = """
        你是一位资深中文小说作者，正在续写长篇小说的一章。严格遵守：
        1. 承接【正文末尾】自然续写，禁止重复或复述已有内容；
        2. 遵循【风格约束】与【角色当前状态】，人物言行不得 OOC；
        3. 参考【前文摘要】与【关键事实】保持设定连续，不得与已确立事实矛盾；
        4. 场景推进参考【本章细纲】，但允许合理的临场发挥；
        5. 对话要有潜台词与动作细节，避免说明文式陈述；
        6. 只输出正文，不要标题、解释、前言或总结。
        """
        let user = """
        \(context.rendered)

        请续写约 \(wordTarget) 字。\((extra?.isEmpty == false) ? "附加要求：\(extra!)" : "")
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    static func rewrite(mode: String, selection: String, instruction: String?) -> [LLMMessage] {
        let system = """
        你是一位资深中文小说编辑。用户会给出一段小说正文并要求\(mode)。严格遵守：
        1. 只输出修改后的完整段落，不要解释修改原因；
        2. 保持原有人称、时态与叙事视角；
        3. 保留原文确立的事实与人物关系，不得引入新设定。
        """
        let user = """
        【原文】
        \(selection)

        【要求】
        \(instruction ?? "无额外要求")
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    static func summarize(content: String, title: String) -> [LLMMessage] {
        let system = """
        你负责为长篇小说章节建立档案。读取章节正文后输出 JSON（不要输出其他内容）：
        {"summary": "120-200字的本章摘要，覆盖主要事件与人物动向", "key_facts": ["本章新确立、后续章节必须记住的事实，每条不超过30字，3-8条"]}
        关键事实只收录不可逆的设定变化：人物状态改变、关系转折、秘密揭露、物品归属、地点变化等。
        """
        return [.init(role: .system, content: system),
                .init(role: .user, content: "【\(title)】\n\(content)")]
    }

    static func creationBlueprint(brief: String) -> [LLMMessage] {
        let system = """
        你是一位资深小说策划。用户给出一句创意，请输出一套可编辑的小说蓝图，严格输出 JSON（不要输出其他内容）：
        {
          "title_suggestion": "书名",
          "theme": "主题与基调（50字内）",
          "synopsis": "200字内的故事梗概",
          "perspective": "叙事视角",
          "style_guide": "文风约束（100字内）",
          "characters": [{"name": "", "role": "主角/配角", "appearance": "", "personality": "", "goal": ""}],
          "worldbuilding": [{"category": "地点/势力/规则/物品", "name": "", "content": ""}],
          "volumes": [{"name": "卷名", "outline": "卷纲（100字内）", "chapters": [{"title": "", "detailed_outline": "细纲（80字内）"}]}]
        }
        第一卷至少给出 3 章细纲，其余卷各 2-3 章占位即可。
        """
        return [.init(role: .system, content: system), .init(role: .user, content: brief)]
    }

    static func creationRevise(blueprintJSON: String, feedback: String) -> [LLMMessage] {
        let system = """
        你是一位资深小说策划。用户已有一套小说蓝图，现在提出修改意见。
        请基于当前蓝图按意见修订，输出修订后的完整蓝图，严格输出 JSON（不要输出其他内容），
        字段结构与原蓝图一致；意见未涉及的字段原样保留，不得遗漏。
        """
        let user = """
        【当前蓝图】
        \(blueprintJSON)

        【修改意见】
        \(feedback)
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    /// 把提供商的「附加系统指令」（ProviderConfig.systemPromptExtra）并入消息：
    /// 首条为 system 时拼接在其后，否则插入为新的首条 system；空/空白指令原样返回。
    static func applying(providerExtra extra: String?, to messages: [LLMMessage]) -> [LLMMessage] {
        guard let trimmed = extra?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return messages
        }
        var result = messages
        if let first = result.first, first.role == .system {
            result[0] = LLMMessage(role: .system, content: first.content + "\n\n" + trimmed)
        } else {
            result.insert(.init(role: .system, content: trimmed), at: 0)
        }
        return result
    }
}

import Foundation

/// 系统提示词装配器：模板文本统一取自 PromptLibrary（出厂默认或用户覆盖），
/// 占位符经 PromptLibrary.render 替换；编辑立即生效，无需重启。
/// 全部调用方均在主线程上下文（@MainActor VM / SwiftUI 视图），故整体标注 MainActor。
@MainActor
enum PromptTemplates {

    static func continueWriting(context: BuiltContext, wordTarget: Int, extra: String?) -> [LLMMessage] {
        let system = PromptLibrary.shared.resolvedText(for: PromptID.continueWriting)
        let user = """
        \(context.rendered)

        请续写约 \(wordTarget) 字。\((extra?.isEmpty == false) ? "附加要求：\(extra!)" : "")
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    static func rewrite(mode: String, selection: String, instruction: String?) -> [LLMMessage] {
        // 「去AI味」走专属模板；其余模式共用通用改写模板
        let system: String
        if mode == "去AI味" {
            system = PromptLibrary.shared.resolvedText(for: PromptID.antiAIFlavor)
        } else {
            let template = PromptLibrary.shared.resolvedText(for: PromptID.rewrite)
            system = PromptLibrary.render(template, values: ["mode": mode])
        }
        let user = """
        【原文】
        \(selection)

        【要求】
        \(instruction ?? "无额外要求")
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    static func summarize(content: String, title: String) -> [LLMMessage] {
        let system = PromptLibrary.shared.resolvedText(for: PromptID.summarize)
        return [.init(role: .system, content: system),
                .init(role: .user, content: "【\(title)】\n\(content)")]
    }

    /// supplement：由「已启用示例标签 + 输入关键词命中」计算出的创作方向补充，
    /// 拼接在系统提示词之后、用户输入之前（不改动用户原始创意文本）。
    static func creationBlueprint(brief: String, supplement: String? = nil) -> [LLMMessage] {
        var system = PromptLibrary.shared.resolvedText(for: PromptID.creationBlueprint)
        if let supplement = supplement?.trimmingCharacters(in: .whitespacesAndNewlines),
           !supplement.isEmpty {
            system += "\n\n" + supplement
        }
        return [.init(role: .system, content: system), .init(role: .user, content: brief)]
    }

    /// supplement：R18 规范等补充约束，拼接在系统提示词之后、用户输入之前。
    static func creationRevise(blueprintJSON: String, feedback: String, supplement: String? = nil) -> [LLMMessage] {
        var system = PromptLibrary.shared.resolvedText(for: PromptID.creationRevise)
        if let supplement = supplement?.trimmingCharacters(in: .whitespacesAndNewlines),
           !supplement.isEmpty {
            system += "\n\n" + supplement
        }
        let user = """
        【当前蓝图】
        \(blueprintJSON)

        【修改意见】
        \(feedback)
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    /// 写作助手系统提示词：{title} 占位符 + 梗概/风格约束条件追加（保持原语义）。
    /// 梗概/风格为用户可无限编辑字段，超长时保留尾部（v1.7 必需层兜底）。
    static func writingAssistantSystem(title: String, synopsis: String, styleGuide: String?) -> String {
        let template = PromptLibrary.shared.resolvedText(for: PromptID.writingAssistant)
        var system = PromptLibrary.render(template, values: ["title": title])
        let cappedSynopsis = tailCapped(synopsis)
        if !cappedSynopsis.isEmpty { system += "\n作品梗概：\(cappedSynopsis)" }
        if let style = styleGuide, !style.isEmpty {
            let cappedStyle = tailCapped(style)
            if !cappedStyle.isEmpty { system += "\n风格约束：\(cappedStyle)" }
        }
        return system
    }

    /// 静默留尾截断（无裁剪上报通道的场景用）：保留末尾 requiredFieldCap 字
    private static func tailCapped(_ text: String,
                                   limit: Int = PromptLimits.requiredFieldCap) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return "……" + String(trimmed.suffix(limit))
    }

    /// 动态注入（R18 规范 / 标签补充 / 读写协议 / 提供商附加指令）先占用输入预算，
    /// 剩余额度才交给 ContextBuilder 装配上下文；扣穿则为 0（必需层仍会发送，可选层全裁）。
    static func adjustedInputBudget(base: Int, injections: String?...) -> Int {
        let used = injections.reduce(0) { $0 + ($1?.count ?? 0) }
        return max(0, base - used)
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

    /// 大纲生成（卷纲/章细纲共用装配）：系统模板按 PromptID 解析（自动支持开发者覆盖），
    /// 用户侧为装配上下文 + 可选附加要求；上下文为空时给出兜底说明。
    static func outline(systemID: String, context: BuiltContext, instruction: String?) -> [LLMMessage] {
        let system = PromptLibrary.shared.resolvedText(for: systemID)
        var user = context.rendered.isEmpty ? "（暂无可用背景信息，请基于常识规划）" : context.rendered
        if let extra = instruction?.trimmingCharacters(in: .whitespacesAndNewlines), !extra.isEmpty {
            user += "\n\n【附加要求】\n\(extra)"
        }
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }
}

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
        let template = PromptLibrary.shared.resolvedText(for: PromptID.rewrite)
        let system = PromptLibrary.render(template, values: ["mode": mode])
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

    static func creationRevise(blueprintJSON: String, feedback: String) -> [LLMMessage] {
        let system = PromptLibrary.shared.resolvedText(for: PromptID.creationRevise)
        let user = """
        【当前蓝图】
        \(blueprintJSON)

        【修改意见】
        \(feedback)
        """
        return [.init(role: .system, content: system), .init(role: .user, content: user)]
    }

    /// 写作助手系统提示词：{title} 占位符 + 梗概/风格约束条件追加（保持原语义）
    static func writingAssistantSystem(title: String, synopsis: String, styleGuide: String?) -> String {
        let template = PromptLibrary.shared.resolvedText(for: PromptID.writingAssistant)
        var system = PromptLibrary.render(template, values: ["title": title])
        if !synopsis.isEmpty { system += "\n作品梗概：\(synopsis)" }
        if let style = styleGuide, !style.isEmpty { system += "\n风格约束：\(style)" }
        return system
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

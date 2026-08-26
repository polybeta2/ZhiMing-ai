import Foundation
import Combine

// MARK: - 提示词体量护栏常量（v1.7 全项目统一引用）

/// 所有上限均为「字符数」。集中定义便于调参与审计。
/// 超限行为：开发者输入保存时截断 / 标签注入熔断跳过 / 必需层字段留尾截断 / 超大请求发送前确认。
enum PromptLimits {
    /// 单条提示词覆盖文本、提供商附加系统指令的硬上限（保存时截断）
    static let maxOverrideChars = 20_000
    /// 单个示例标签 presetText 的硬上限（保存时截断）
    static let maxTagPresetChars = 20_000
    /// 「标签智能注入」单次请求的合计熔断线（超出部分跳过并附提示）
    static let matchedSupplementCap = 8_000
    /// R18 特化模块单次请求的合计字符预算（小模块优先装填）
    static let r18ModuleCharBudget = 12_000
    /// 必需层字段（风格约束/梗概/卷纲/细纲等）的兜底截断线（保留尾部）
    static let requiredFieldCap = 4_000
    /// 写作助手聊天历史的单条消息截断线
    static let historyMessageCap = 2_000
    /// 发送前总字符告警线：超过则弹确认框（PromptGuard）
    static let requestWarnChars = 80_000
}

// MARK: - 示例标签数据模型（一句话立项增强）

/// 单个示例标签：用户「启用」且输入命中关键词时，presetText 注入蓝图生成的系统提示词
struct PromptTag: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var keywords: [String]      // 触发注入的关键词（含标签名本身）
    var presetText: String      // 完整预设提示词内容（可在开发者功能中编辑）
}

struct PromptTagCategory: Codable, Identifiable, Equatable {
    var id: String
    var name: String            // 小说类型 / 内容流派 / 风格基调
    var tags: [PromptTag]
}

// MARK: - 内置提示词条目

struct BuiltInPrompt: Identifiable {
    let id: String
    let name: String            // 展示名
    let category: String        // 分类（写作 / 立项 / 档案 / 助手）
    let placeholders: [String]  // 模板占位符说明
    let defaultText: String     // 出厂默认文本（不落盘，仅作回退）
}

/// 稳定的提示词 ID 常量
enum PromptID {
    static let continueWriting = "prompt.continue.system"
    static let rewrite = "prompt.rewrite.system"
    static let summarize = "prompt.summarize.system"
    static let creationBlueprint = "prompt.creation.blueprint.system"
    static let creationRevise = "prompt.creation.revise.system"
    static let writingAssistant = "prompt.assistant.system"
    static let assistantReadWrite = "prompt.assistant.rw.protocol"
    static let antiAIFlavor = "prompt.antiai.system"
    static let volumeOutline = "prompt.volume.outline.system"
    static let chapterOutline = "prompt.chapter.outline.system"
    static let r18zh = "prompt.r18.system.zh"
    static let r18en = "prompt.r18.system.en"
}

// MARK: - 提示词与标签库（全局单例）

/// 应用级配置仓库：
/// 1. 六套内置系统提示词的「用户覆盖文本」（未覆盖时回退出厂默认）；
/// 2. 一句话立项的示例标签库（分类 / 关键词 / 完整预设内容），支持开发者增删改。
/// 持久化：Application Support/ZhiMing/prompts.json（原子写入，独立于 library.json）。
@MainActor
final class PromptLibrary: ObservableObject {
    static let shared = PromptLibrary()

    /// 提示词覆盖表：id -> 用户自定义文本；为空表示使用出厂默认
    @Published private(set) var overrides: [String: String] = [:]
    /// 示例标签库（三类，可扩展）
    @Published var tagCategories: [PromptTagCategory] = []

    /// 全部内置提示词清单（开发者功能列表数据源）
    let builtInPrompts: [BuiltInPrompt]

    private struct Document: Codable {
        var version: Int = 1
        var overrides: [String: String]
        var tagCategories: [PromptTagCategory]
    }

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json")
    }

    /// 备份文件（单代，随每次保存同步刷新）
    static var backupURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ZhiMing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json.bak")
    }

    private init() {
        builtInPrompts = Self.makeBuiltInPrompts()
        if let doc = Self.decodeDocument(at: Self.fileURL) ?? Self.decodeDocument(at: Self.backupURL) {
            overrides = doc.overrides
            tagCategories = doc.tagCategories.isEmpty ? Self.defaultTagCategories() : doc.tagCategories
        } else {
            // 主/备均不可读：隔离损坏文件（不原地覆盖），回到出厂标签库
            if FileManager.default.fileExists(atPath: Self.fileURL.path)
                || FileManager.default.fileExists(atPath: Self.backupURL.path) {
                Self.quarantineUnreadableFiles()
            }
            tagCategories = Self.defaultTagCategories()
        }
    }

    private static func decodeDocument(at url: URL) -> Document? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Document.self, from: data)
    }

    private static func quarantineUnreadableFiles() {
        let stamp = Int(Date().timeIntervalSince1970)
        for url in [fileURL, backupURL] where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.moveItem(at: url, to: URL(fileURLWithPath: url.path + ".corrupt-\(stamp)"))
        }
    }

    /// 原子保存 + 同步刷新备份（文件小，双写成本可忽略）；提示词库属低危数据，失败不打断创作流
    func save() {
        let doc = Document(overrides: overrides, tagCategories: tagCategories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(doc) else { return }
        do {
            try data.write(to: Self.fileURL, options: [.atomic])
            try? data.write(to: Self.backupURL, options: [.atomic])
        } catch {
            // 静默即可：overrides/tags 可随时由出厂默认重建
        }
    }

    // MARK: 提示词读取与覆盖

    /// 当前生效文本：用户覆盖优先，否则出厂默认
    func resolvedText(for id: String) -> String {
        guard let prompt = builtInPrompts.first(where: { $0.id == id }) else { return "" }
        return overrides[id] ?? prompt.defaultText
    }

    func isCustomized(_ id: String) -> Bool { overrides[id] != nil }

    /// 保存覆盖；若与出厂默认一致则移除覆盖（保持文档干净）。
    /// 硬上限：超长文本截断到 maxOverrideChars——覆盖文本会原样进每次请求，必须封顶。
    func setOverride(_ id: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let prompt = builtInPrompts.first(where: { $0.id == id }),
           trimmed == prompt.defaultText.trimmingCharacters(in: .whitespacesAndNewlines) {
            overrides.removeValue(forKey: id)
        } else {
            overrides[id] = String(text.prefix(PromptLimits.maxOverrideChars))
        }
        save()
    }

    /// 恢复出厂默认
    func resetOverride(_ id: String) {
        overrides.removeValue(forKey: id)
        save()
    }

    /// 占位符替换：模板中的 {key} 替换为对应值；未提供的占位符替换为空串
    static func render(_ template: String, values: [String: String]) -> String {
        var out = template
        // 先收集模板里实际出现的占位符键，避免遗漏清理
        let known = ["mode", "title", "synopsis", "styleGuide"]
        for key in known {
            let token = "{\(key)}"
            guard out.contains(token) else { continue }
            out = out.replacingOccurrences(of: token, with: values[key] ?? "")
        }
        return out
    }

    // MARK: 智能注入匹配（隐性使用机制）

    /// 规则：仅当「标签已被启用」且「输入包含该标签关键词」时返回其预设内容；
    /// 未启用 → 绝不注入；全部未启用或无一命中 → 返回 nil（只发原始输入）。
    /// 熔断：命中内容合计超过 matchedSupplementCap 时跳过放不下的条目并附提示，
    /// 防止「大量启用标签 + 输入凑齐全部关键词」把 system 撑到 MB 级。
    func matchedSupplement(enabledIDs: [String], input: String) -> String? {
        guard !enabledIDs.isEmpty, !input.isEmpty else { return nil }
        var lines: [String] = []
        var used = 0
        var dropped = 0
        for category in tagCategories {
            for tag in category.tags where enabledIDs.contains(tag.id) {
                let hit = input.contains(tag.name)
                    || tag.keywords.contains(where: { !$0.isEmpty && input.contains($0) })
                guard hit else { continue }
                let line = "◆ \(tag.name)：\(tag.presetText)"
                if used + line.count > PromptLimits.matchedSupplementCap {
                    dropped += 1
                    continue
                }
                lines.append(line)
                used += line.count
            }
        }
        guard !lines.isEmpty else { return nil }
        var body = "【创作方向补充】\n以下为作者启用的创作方向约束，规划蓝图（题材、人物、世界观、卷章节奏）时必须严格遵循：\n"
            + lines.joined(separator: "\n")
        if dropped > 0 {
            body += "\n\n（另有 \(dropped) 条命中标签因合计注入量超过 \(PromptLimits.matchedSupplementCap) 字上限，本次未注入）"
        }
        return body
    }

    // MARK: R18 增强（fictional-erotica 双语规范，语言分离注入）

    /// 输入语言检测："zh" / "en"。
    /// 统计 CJK 表意字符与拉丁字母占比；完全无文字时默认中文（应用主语言）；
    /// 占比相同（中英混合平局）时按最后一句的构成判定。
    static func detectLanguage(_ text: String) -> String {
        var cjk = 0, latin = 0
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0xF900...0xFAFF).contains(v) {
                cjk += 1
            } else if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) {
                latin += 1
            }
        }
        if cjk == 0 && latin == 0 { return "zh" }
        if cjk == latin {
            let parts = text.split(whereSeparator: { ".!?。！？；;\n".contains($0) })
            let lastSentence = parts.last.map(String.init) ?? text
            var c2 = 0, l2 = 0
            for scalar in lastSentence.unicodeScalars {
                let v = scalar.value
                if (0x4E00...0x9FFF).contains(v) { c2 += 1 }
                else if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) { l2 += 1 }
            }
            return c2 >= l2 ? "zh" : "en"
        }
        return cjk > latin ? "zh" : "en"
    }

    /// R18 增强的资源查找：SwiftPM 资源在 iOS 上位于 ZhiMing_ZhiMing.bundle，
    /// 查不到时回退 Bundle.main（兼容 macOS / 预览）。
    private static let skillPackRoot: Bundle = {
        if let url = Bundle.main.url(forResource: "ZhiMing_ZhiMing", withExtension: "bundle"),
           let inner = Bundle(url: url) {
            return inner
        }
        return Bundle.main
    }()

    // MARK: - fictional-erotica 模块路由（核心常驻 + 特化模块按需加载）

    /// 特化模块路由表：命中任一关键词才把该模块注入本次请求（对应上游 progressive disclosure）
    struct R18ModuleRoute {
        let file: String          // SkillPacks 内文件名（不含扩展名）
        let title: String         // 注入时的分节标题
        let keywords: [String]    // 中英混合关键词，小写匹配
    }

    static let r18ModuleRoutes: [R18ModuleRoute] = [
        R18ModuleRoute(file: "craft-controls", title: "技法控制台（高级场景构建/修订）",
            keywords: ["console", "控制台", "多阶段", "长镜头", "反复修改", "打磨", "修订", "节奏敏感"]),
        R18ModuleRoute(file: "persona-and-continuity", title: "人设与跨场景连续性",
            keywords: ["人设", "连续性", "跨场景", "可复用人物", "recurring", "多人", "三人", "群体", "poly", "threesome"]),
        R18ModuleRoute(file: "sexual-roles", title: "攻受与行为角色",
            keywords: ["攻受", "总攻", "总受", "top", "bottom", "switch", "gong", "shou", "插入位", "行为角色", "角色分配"]),
        R18ModuleRoute(file: "language-and-dialogue", title: "语言与对白校准",
            keywords: ["对白", "台词", "dirty talk", "情话", "语言风格", "语气", "声线", "dialogue"]),
        R18ModuleRoute(file: "play-and-props", title: "玩法与道具",
            keywords: ["道具", "玩具", "捆绑", "绳缚", "kink", "sm", "调教", "play", "玩法"]),
        R18ModuleRoute(file: "speculative-anatomy", title: "幻想身体结构（人外）",
            keywords: ["人外", "非人类", "非人", "兽人", "龙人", "蛇人", "触手", "异种", "怪物", "monster", "nonhuman", "tentacle"]),
        R18ModuleRoute(file: "canon-grounding-and-fanfiction", title: "同人原作锚定",
            keywords: ["同人", "二创", "原作", "canon", "au", "漫改", "性转", "ooc", "fanfiction"]),
        R18ModuleRoute(file: "core-calibration", title: "输出校准诊断",
            keywords: ["模板化", "太平淡", "干瘪", "不够色", "诊断", "校准", "generic", "水词"])
    ]

    /// 单次请求特化模块的总字符预算（含 core 之后追加的全部模块正文）。
    /// v1.7 起以「预算」取代旧「最多 4 个」：个数不限总量、大模块会霸占名额，
    /// 改为小模块优先装填，保证注入量有硬上界。
    private static let moduleCharBudget = PromptLimits.r18ModuleCharBudget

    /// 读取本地包内单个模块文件（零网络依赖）。language: "zh"/"en"
    static func bundledSkillFile(_ name: String, language: String) -> String? {
        guard let url = skillPackRoot.url(
            forResource: name,
            withExtension: "md",
            subdirectory: "SkillPacks/fictional-erotica/\(language)"
        ), let text = try? String(contentsOf: url, encoding: .utf8),
           !text.isEmpty else { return nil }
        return text
    }

    /// 按输入主语言组装 R18 规范——中英永不混合注入：
    /// 核心（SKILL.md 契约）常驻，其后按关键词命中的特化模块在字符预算内装填。
    /// 优先级：开发者覆盖文本 > 本地打包 Skill > 出厂精简版。
    /// 调用方负责先判断 novel.r18Enabled。
    func r18Supplement(forInput input: String) -> String {
        let lang = Self.detectLanguage(input)
        let id = lang == "en" ? PromptID.r18en : PromptID.r18zh
        if let override = overrides[id],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }

        guard var core = Self.bundledSkillFile("core", language: lang) else {
            return resolvedText(for: id)   // 包缺失：出厂精简版兜底
        }
        // 核心里的路由节已被提取脚本移除，这里补一行运行时路由说明
        core += "\n\n> 以下按本次请求命中的关键词加载对应特化模块。"

        // 1) 收集全部命中模块 → 2) 小模块优先在预算内贪心装填 → 3) 按路由表顺序拼接输出
        let lowered = input.lowercased()
        var hits: [(file: String, title: String, text: String)] = []
        for route in Self.r18ModuleRoutes {
            guard route.keywords.contains(where: { lowered.contains($0.lowercased()) }) else { continue }
            guard let text = Self.bundledSkillFile(route.file, language: lang) else { continue }
            hits.append((route.file, route.title, text))
        }
        hits.sort { $0.text.count < $1.text.count }

        var used = core.count
        var chosen: [String: String] = [:]      // file -> text（保持去重）
        for hit in hits {
            if used + hit.text.count > Self.moduleCharBudget { break }   // 升序排列：装不下则后面更大，直接停
            used += hit.text.count
            chosen[hit.file] = hit.text
        }

        var loaded: [String] = []
        for route in Self.r18ModuleRoutes {
            guard let text = chosen[route.file] else { continue }
            core += "\n\n### § 特化模块：\(route.title)\n\n" + text
            loaded.append(route.file)
        }
        #if DEBUG
        let overflow = hits.count - loaded.count
        print("[R18] 语言=\(lang) 注入模块=\(loaded.isEmpty ? "仅core" : loaded.joined(separator: ", "))"
            + (overflow > 0 ? "（\(overflow) 个命中模块超预算未注入）" : ""))
        #endif
        return core
    }

    // MARK: 标签库维护（开发者功能）

    func upsertTag(_ tag: PromptTag, categoryId: String) {
        var tag = tag
        // 硬上限：presetText 会整段注入蓝图 system，必须封顶（保存时截断）
        if tag.presetText.count > PromptLimits.maxTagPresetChars {
            tag.presetText = String(tag.presetText.prefix(PromptLimits.maxTagPresetChars))
        }
        guard let index = tagCategories.firstIndex(where: { $0.id == categoryId }) else { return }
        if let tagIndex = tagCategories[index].tags.firstIndex(where: { $0.id == tag.id }) {
            tagCategories[index].tags[tagIndex] = tag
        } else {
            tagCategories[index].tags.append(tag)
        }
        save()
    }

    func deleteTag(_ tag: PromptTag, categoryId: String) {
        guard let index = tagCategories.firstIndex(where: { $0.id == categoryId }) else { return }
        tagCategories[index].tags.removeAll { $0.id == tag.id }
        save()
    }

    // MARK: 出厂数据

    private static func makeBuiltInPrompts() -> [BuiltInPrompt] {
        [
            BuiltInPrompt(
                id: PromptID.continueWriting,
                name: "续写 · 系统提示词",
                category: "写作",
                placeholders: [],
                defaultText: """
                你是一位资深中文小说作者，正在续写长篇小说的一章。严格遵守：
                1. 承接【正文末尾】自然续写，禁止重复或复述已有内容；
                2. 遵循【风格约束】与【角色当前状态】，人物言行不得 OOC；
                3. 参考【前文摘要】与【关键事实】保持设定连续，不得与已确立事实矛盾；
                4. 场景推进参考【本章细纲】，但允许合理的临场发挥；
                5. 对话要有潜台词与动作细节，避免说明文式陈述；
                6. 只输出正文，不要标题、解释、前言或总结。
                """
            ),
            BuiltInPrompt(
                id: PromptID.rewrite,
                name: "改写/润色/扩写 · 系统提示词",
                category: "写作",
                placeholders: ["{mode}＝操作名（改写/润色/扩写）"],
                defaultText: """
                你是一位资深中文小说编辑。用户会给出一段小说正文并要求{mode}。严格遵守：
                1. 只输出修改后的完整段落，不要解释修改原因；
                2. 保持原有人称、时态与叙事视角；
                3. 保留原文确立的事实与人物关系，不得引入新设定。
                """
            ),
            BuiltInPrompt(
                id: PromptID.antiAIFlavor,
                name: "去 AI 味 · 系统提示词",
                category: "写作",
                placeholders: [],
                defaultText: """
                你是一位专责「去机器腔」的中文小说编辑。用户给出一段正文（可能附带本地检测结果），请只改表达、不改内容：
                1. 剧情、对话语义、人物语气、专有名词与设定一律保留；不增删情节信息，不引入新设定；
                2. 清除解释性对举句式（「不是……而是……」式说明腔），改为动作与画面直接呈现；
                3. 删减万能比喻（「仿佛/犹如/宛如」式滥用），全段至多保留一处必要的；
                4. 拆掉「让/令/使 + 抽象感受」的强加因果，换成角色可观察的行为反应；
                5. 少用「意识到/感到/明白/心中一凛」类认知直陈，情绪经身体细节与环境互动外化；
                6. 替换高频模板神态动作（瞳孔特写、倒吸凉气、勾唇、心中涌起一类），换成贴合人物习惯的具体小动作；
                7. 打破句长均一：长短句交替，连续等长的段落必须变奏；「了」字过密处改完成态或直接动词；
                8. 幅度护栏：以词句为单位微调，不做整段重写；拿不准的地方保持原样；
                9. 若给出【本地体检结果】，逐项优先处理其指出的问题；
                10. 只输出修改后的正文，不要解释、对照表或总结。
                """
            ),
            BuiltInPrompt(
                id: PromptID.summarize,
                name: "章节摘要建档 · 系统提示词",
                category: "档案",
                placeholders: [],
                defaultText: """
                你负责为长篇小说章节建立档案。读取章节正文后输出 JSON（不要输出其他内容）：
                {"summary": "120-200字的本章摘要，覆盖主要事件与人物动向", "key_facts": ["本章新确立、后续章节必须记住的事实，每条不超过30字，3-8条"]}
                关键事实只收录不可逆的设定变化：人物状态改变、关系转折、秘密揭露、物品归属、地点变化等。
                """
            ),
            BuiltInPrompt(
                id: PromptID.creationBlueprint,
                name: "立项蓝图生成 · 系统提示词",
                category: "立项",
                placeholders: [],
                defaultText: """
                你是一位资深小说策划。用户给出一句创意，请输出一套可编辑的小说蓝图，严格输出 JSON（不要输出其他内容）：
                {
                  "title_suggestion": "书名",
                  "theme": "主题与基调（50字内）",
                  "synopsis": "200字内的故事梗概",
                  "perspective": "叙事视角",
                  "style_guide": "文风约束（100字内）",
                  "characters": [{"name": "", "role": "主角/配角", "appearance": "", "personality": "", "goal": ""}],
                  "worldbuilding": [{"category": "地点/势力/规则/物品", "name": "", "content": ""}],
                  "volumes": [{"name": "卷名", "outline": "卷纲（100字内）", "emotion_arc": [], "conflict_ladder": [], "info_gap": {"start": "", "end": ""}, "chapters": [{"title": "", "detailed_outline": "细纲（80字内）", "scene_cards": [{"goal": "", "obstacle": "", "hook": ""}]}]}]
                }
                卷对象请额外给出三个规划维度：
                - "emotion_arc"：本卷情绪走向 4-6 拍的数组，如 ["压抑","压抑","提升","打脸"]；
                - "conflict_ladder"：冲突阶梯数组，核心冲突拆 2-4 层逐级升高，每层 {"level": 层序, "obstacle": 该层阻力, "turning_point": 跨入该层的转折点}；
                - "info_gap"：信息差，start=卷初读者与主角知道什么，end=卷末将揭示或颠覆什么。
                每章对象请给出 "scene_cards"：1-3 张场景卡，每张 {"goal": 主角这场想达成什么, "obstacle": 什么拦着, "hook": 章末勾住读者的悬念}。
                第一卷必须完整填写上述维度；其余卷至少给 emotion_arc 与 info_gap。
                第一卷至少给出 3 章细纲，其余卷各 2-3 章占位即可。
                """
            ),
            BuiltInPrompt(
                id: PromptID.creationRevise,
                name: "立项蓝图修订 · 系统提示词",
                category: "立项",
                placeholders: [],
                defaultText: """
                你是一位资深小说策划。用户已有一套小说蓝图，现在提出修改意见。
                请基于当前蓝图按意见修订，输出修订后的完整蓝图，严格输出 JSON（不要输出其他内容），
                字段结构与原蓝图一致；意见未涉及的字段原样保留，不得遗漏。
                """
            ),
            BuiltInPrompt(
                id: PromptID.volumeOutline,
                name: "卷纲生成 · 系统提示词",
                category: "大纲",
                placeholders: [],
                defaultText: """
                你是一位资深中文长篇小说策划，为指定的一卷撰写「卷纲」。严格遵守：
                1. 承接【作品梗概】【风格约束】与【前文摘要】，延续【最近正文节选】的实际走向，不与已确立事实矛盾；
                2. 概述本卷核心冲突、2-4 个关键转折与卷末落点，体现主角目标的推进或变化；
                3. 若给出【当前卷纲】，视为修订而非重起，保留仍然成立的内容；
                4. 参考【全书结构】控制本卷容量，不越界写其他卷的核心事件；
                5. 只输出卷纲正文（约 150-300 字），不要标题、解释或前言；
                6. 若本次对情绪走向 / 冲突阶梯 / 信息差有调整，在回复末尾追加一个 ```zm-dims``` 围栏，内为严格 JSON（三个字段均可省略）：
                {"emotion_arc":["压抑","提升","打脸"],"conflict_ladder":[{"obstacle":"该层阻力","turning_point":"跨入该层的转折"}],"info_gap":{"start":"卷初已知","end":"卷末揭示"}}
                冲突阶梯无需写 level，将按给出顺序从 1 编号；无维度调整则不要输出该围栏。
                """
            ),
            BuiltInPrompt(
                id: PromptID.chapterOutline,
                name: "章细纲生成 · 系统提示词",
                category: "大纲",
                placeholders: [],
                defaultText: """
                你是一位资深中文小说编辑，为指定章节撰写「章细纲」（写作前的执行大纲）。严格遵守：
                1. 承接【上一章】的收束并为【下一章】留出接口，遵循【所在卷】卷纲的节奏；
                2. 若有【当前细纲】或【本章已写正文末尾】，视为修订而非重起，与已确立事实保持一致；
                3. 写明本章场景、出场角色、核心冲突、推进节拍（2-4 拍）与章末钩子；
                4. 人物动机须符合【角色当前状态】，不得引入未经确认的新设定；
                5. 只输出细纲正文（约 120-250 字），不要标题与解释；
                6. 在回复末尾追加一个 ```zm-scene``` 围栏，内为本章 1-3 张场景卡的严格 JSON 数组：
                [{"goal":"主角这场想达成什么","obstacle":"什么拦着","hook":"章末悬念钩子"}]
                细纲正文不必复述卡片清单；确实无法分场时可省略该围栏。
                """
            ),
            BuiltInPrompt(
                id: PromptID.assistantReadWrite,
                name: "写作助手 · 读写协议",
                category: "助手",
                placeholders: [],
                defaultText: """
                【写作助手 · 读写协议（作者已开启读写模式）】
                你可以提议修改本书设定，但必须遵守：
                1. 仅当作者的请求明确要求修改时才输出补丁；纯咨询、头脑风暴一律不输出补丁；
                2. 补丁放在回复末尾的一个 ```zm-patch 围栏代码块中，每条回复至多一个；
                3. 围栏内是严格 JSON，所有字段均可省略，结构如下：
                {"summary":"本次改动一句话说明","character_updates":[{"find":"角色名或别名","set":{"currentGoal":"新目标"}}],"character_adds":[{"name":"姓名","personality":"…"}],"world_upserts":[{"category":"地点/势力/规则/物品/其他","name":"条目名","content":"完整内容"}],"novel_updates":{"synopsis":"…","perspective":"…","styleGuide":"…"}}
                4. character_updates.set 可用字段：name、aliases（顿号分隔）、appearance、personality、background、currentGoal、currentLocation、physicalState、mentalState、isSceneRelevant("true"/"false")；
                5. 不支持删除角色/世界观/卷/章本体；更新角色时只提交需要变化的字段，不要整卡重写；
                6. 围栏之外的正文先用自然语言说明你打算改什么、为什么，随后等待作者确认——未经确认不会生效；
                7. 重命名卷/章仅在作者明确要求时输出：
                "volume_renames":[{"find":"现有卷名或第N卷","to":"新卷名"}]
                "chapter_renames":[{"find":"现有章题（可加「卷名/」前缀消歧）","to":"新章题"}]
                8. 章节场景卡细粒度操作（index 从 1 起）：
                "scene_cards":[{"chapter":"章题","update":[{"index":2,"hook":"新钩子"}],"add":[{"goal":"","obstacle":"","hook":""}],"remove":[3]}]
                其中 "replace":[{"goal":"","obstacle":"","hook":""}] 为整组替换，与 update/add/remove 互斥。
                """
            ),
            BuiltInPrompt(
                id: PromptID.writingAssistant,
                name: "写作助手 · 系统提示词",
                category: "助手",
                placeholders: ["{title}＝书名"],
                defaultText: """
                你是小说《{title}》的写作助手，帮助作者头脑风暴、解答剧情与技法问题，回答简洁具体。
                """
            ),
            BuiltInPrompt(
                id: PromptID.r18zh,
                name: "R18 规范 · 中文版（fictional-erotica）",
                category: "R18",
                placeholders: [],
                defaultText: """
                【R18 虚构情色写作规范（fictional-erotica · 中文版，作者已确认启用）】
                本书为面向成年读者的虚构小说。涉及亲密场景时遵循：
                1. 核心原则：性场景是人物切片与关系现场，不是可替换的动作序列；递进来自行动、认知、情感、权力、身体状态、注意力或关系中有意义的改变、深化、延迟或有意维持，而非机械加码；
                2. 人物声带：每个角色保留自己的语言习惯与欲望表达方式，禁止集体套用模板化色情台词；
                3. 身体连续：衣物、双手、姿势、视线与物件在动作间保持连续，位置变化要有过程；
                4. 内在视角：感觉、念头、欲望与关系同时流动但互不混淆，贴近当下，不写成关系分析报告；
                5. 明确度控制：默认 open-door（可直白），词汇语域 direct-neutral（直接而中性），避免器官清单式罗列与委婉语迷雾；作者另有指定时按指定执行（closed / sensual / open-door / explicit）；
                6. 自愿前提：角色间互动以相互意愿为前提，犹豫、拒绝等信号必须被对方尊重；
                7. 场景收束：允许升级、停顿、改道或保持未解决，不必强行对称高潮；结束后给出情绪落点与关系变化。
                本规范仅用于虚构创作，输出仍受所配置模型能力边界约束。
                """
            ),
            BuiltInPrompt(
                id: PromptID.r18en,
                name: "R18 Standard · English (fictional-erotica)",
                category: "R18",
                placeholders: [],
                defaultText: """
                [R18 Fictional Erotica Writing Standard — fictional-erotica, English edition, author-enabled]
                This book is adult-oriented fiction. For intimate scenes:
                1. Core principle: a sex scene is a slice of character and a live expression of relationship dynamics — progression means meaningful change, deepening, deferral, or deliberate hold in action, knowledge, feeling, power, body state, attention, or relationship; never mechanical escalation;
                2. Character voice: each character keeps their own speech patterns and desire vocabulary; never collapse them into one stock porn voice;
                3. Embodied continuity: clothing, hands, positions, gaze, and objects stay continuous between beats; every change of position has a process;
                4. Close interiority: sensation, thought, desire, and relationship move together without collapsing into one another — stay in the moment, never narrate relationship analysis;
                5. Explicitness controls: default open-door with a direct-neutral lexical register; readable anatomy and action without clinical inventory or euphemistic fog; honor any author override (closed / sensual / open-door / explicit);
                6. Consent premise: mutual willingness is the precondition of any scene; hesitation or refusal signals must be respected by the other character;
                7. Scene movement: scenes may escalate, pause, redirect, fail, or remain unresolved without compulsory symmetry or climax; land the emotional aftermath and the relationship shift afterwards.
                For fictional use only; output remains subject to the configured model's capabilities.
                """
            ),
        ]
    }

    /// 三类十五个初始示例标签（开发者可在应用内增删改）
    static func defaultTagCategories() -> [PromptTagCategory] {
        [
            PromptTagCategory(id: "cat.genre", name: "小说类型", tags: [
                PromptTag(id: "tag.lightnovel", name: "轻小说", keywords: ["轻小说"], presetText:
                    "以轻小说笔法规划：节奏明快，单场景信息密度低；主角设定带一个鲜明的「萌点」或反差标签；大量生活化对白与内心吐槽，段落短促；卷首 3 章内必须完成金手指展示与第一个小高潮；避免大段环境描写与复杂多线叙事。"),
                PromptTag(id: "tag.mystery", name: "推理小说", keywords: ["推理", "侦探", "凶案", "诡计"], presetText:
                    "按本格推理规范规划：开篇 3 章内抛出核心谜面（密室/不在场证明/失踪）；线索公平分布，关键证据在前文必须出现过；设计一层误导性伪解答与一层真解答；红鲱鱼角色不超过两个；诡计需在现实逻辑内自洽，禁止超自然作弊。"),
                PromptTag(id: "tag.scifi", name: "科幻小说", keywords: ["科幻", "星际", "赛博朋克", "末世", "AI"], presetText:
                    "以硬科幻质感规划：确立一个贯穿全书的核心科幻奇观与技术规则（如曲率航行、记忆上传、生态崩溃），所有冲突围绕该设定的限制展开；技术代价与副作用要具体；社会形态随技术推演；避免出现与已立物理规则矛盾的情节。"),
                PromptTag(id: "tag.fantasy", name: "奇幻小说", keywords: ["奇幻", "魔法", "异世界", "龙", "精灵"], presetText:
                    "按史诗奇幻框架规划：先建立自洽的力量体系（魔法来源、施法代价、等级边界），战斗胜负必须受体系约束；种族与势力地图清晰，每个地名首次出现时给出一句氛围白描；主线围绕一件古老遗物或一个预言推进；保留至少一个非人视角的支线。"),
                PromptTag(id: "tag.romance", name: "言情小说", keywords: ["言情", "恋爱", "甜宠", "爱情"], presetText:
                    "以情感线为主轴规划：男女主各自有独立的职业目标与性格缺陷，感情推进由事件驱动而非巧合堆砌；每卷设置一次关系危机与一次心动峰值；对手戏注重潜台词与肢体细节；结局走向与情感浓度匹配，避免强行降智误会。"),
            ]),
            PromptTagCategory(id: "cat.school-of-flow", name: "内容流派", tags: [
                PromptTag(id: "tag.infiniteflow", name: "无限流", keywords: ["无限流", "副本", "轮回空间"], presetText:
                    "按无限流结构规划：主神空间/轮回系统的规则三章内讲清（积分、兑换、惩罚机制）；每个副本是一个封闭谜题，有独立恐怖/生存主题与通关条件；队友配置兼顾战力与背刺可能；副本间穿插主世界的成长线与隐藏真相铺垫。"),
                PromptTag(id: "tag.campusflow", name: "学院流", keywords: ["学院流", "学院", "校园", "入学"], presetText:
                    "以学院体系为核心舞台规划：学院的等级/考核/社团/禁地规则明确且被反复使用；同学关系是主要人际网络，竞争者、室友、导师各司其职；升级节奏绑定学期节点（月考→期末→学年末大比）；校园之外的世界观通过课程与传说逐步揭开。"),
                PromptTag(id: "tag.transmigration", name: "穿越流", keywords: ["穿越", "穿书", "快通", "快穿"], presetText:
                    "按穿越叙事规范规划：现代知识/记忆与异世界规则的错位是前期核心笑点与爽点来源；原主遗留的人际债与身份谜团要在前两卷清算完毕；金手指克制且有限制条款；保留一条「能否回归原世界」的情感暗线作为后期抉择。"),
                PromptTag(id: "tag.rebirth", name: "重生流", keywords: ["重生", "重回", "重来一世"], presetText:
                    "按重生流规范规划：重生者携带的未来信息是资源也是诅咒——每次预知兑现都会偏移时间线；前世仇敌的崛起路径给出合理动因而非脸谱化恶；利用先知优势时要付出代价（失去先机、暴露异常）；中期让时间线偏离到先知彻底失效，逼主角靠自身实力。"),
                PromptTag(id: "tag.systemflow", name: "系统流", keywords: ["系统流", "系统", "金手指", "签到", "面板"], presetText:
                    "按系统流规范规划：系统面板字段（属性/任务/商城）第一章内亮相但不过度刷屏；系统任务驱动章节节奏，奖励与惩罚都要落在具体剧情上；系统本身留有人格化或来历悬念作为长线伏笔；数值膨胀控制在可感知范围内，避免秒天秒地。"),
            ]),
            PromptTagCategory(id: "cat.tone", name: "风格基调", tags: [
                PromptTag(id: "tag.sweet", name: "高糖无刀", keywords: ["高糖", "无刀", "甜文", "撒糖"], presetText:
                    "全程高糖基调：无重大角色伤亡、无背叛刀点；矛盾限于误会、吃醋与外部阻力且当章化解；每章至少一场高甜互动（日常投喂、护短、双向奔赴）；反派威胁存在但不伤害主角团核心情感；结尾必留糖。"),
                PromptTag(id: "tag.brainy", name: "剧情烧脑", keywords: ["烧脑", "反转", "伏笔", "悬疑"], presetText:
                    "烧脑叙事标准：每卷埋设不少于三条跨卷伏笔并在后续回收；关键真相采用多层反转（第一层看似合理、第二层颠覆动机、第三层重构时间线）；信息差驱动悬念，读者视角始终少于主角或早于主角半步；杜绝靠隐瞒关键信息制造假悬念。"),
                PromptTag(id: "tag.slicelife", name: "轻松日常", keywords: ["轻松", "日常", "搞笑", "沙雕"], presetText:
                    "轻松日常基调：单元剧结构为主，每章一个完整小事件；幽默来自角色性格错位与吐槽互动，不靠刻意装疯卖傻；无沉重主线压迫感，长线目标以背景板形式缓慢推进；允许偶尔温情瞬间调剂，但整体保持松弛治愈。"),
                PromptTag(id: "tag.dark", name: "暗黑悬疑", keywords: ["暗黑", "致郁", "压抑", "克苏鲁"], presetText:
                    "暗黑悬疑基调：世界观底色残酷，规则冰冷且执行到位（主要角色可以死）；恐惧来自未知与不可抗力而非血浆堆砌；真相层层剥离但每层都更令人绝望；保留一点微弱的人性微光作为情绪锚点；避免无意义的虐，所有黑暗服务于主题表达。"),
                PromptTag(id: "tag.hotblooded", name: "热血燃向", keywords: ["热血", "燃", "战斗", "升级"], presetText:
                    "热血燃向基调：以「绝境→爆发→逆转」为标准战斗曲线；主角每一次变强都要有明确的努力或代价支撑；伙伴羁绊与对手敬意并重，宿敌要有值得尊重的理由；关键战役前必有蓄力铺垫，胜利瞬间给足仪式感；口号式台词克制使用，燃点靠行动兑现。"),
            ]),
        ]
    }
}

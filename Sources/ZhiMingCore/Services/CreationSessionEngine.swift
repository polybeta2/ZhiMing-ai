import Foundation

// MARK: - 立项状态机的类型与结算产出

/// 立项阶段（原 CreationSessionViewModel.Phase，随状态机核心下沉 Core）
public enum CreationPhase: String, Codable, Equatable {
    case collecting, proposing, blueprintReady, outlining, confirmed
}

/// 立项会话的流类别（原 CreationSessionViewModel.StreamKind）
public enum CreationStreamKind: String {
    case clarify, structure, foundation, revise, volumeBatch, chapterBatch, chapterNames
}

/// 一次流结算的全部产出：VM 据此同步镜像、展示消息并调度后续请求
public struct CreationSettleOutcome {
    public var state: CreationSessionState
    /// 助手气泡文本（nil 不追加）
    public var message: String?
    /// 解析失败等错误提示（进 VM 的 errorMessage）
    public var error: String?
    /// 满足自动连续条件（开关开启且有剩余），VM 负责延时执行下一批
    public var autoNext: Bool
    /// 状态机要求的下一步请求（如澄清通过后自动接结构规划）
    public var nextStep: NextStep?

    public enum NextStep { case requestStructure }

    init(state: CreationSessionState, message: String?, error: String?,
         autoNext: Bool = false, nextStep: NextStep? = nil) {
        self.state = state
        self.message = message
        self.error = error
        self.autoNext = autoNext
        self.nextStep = nextStep
    }
}

// MARK: - 立项会话状态机核心

/// 立项状态机的纯逻辑核心（从 CreationSessionViewModel 抽出，v2.2.1 测试基线）：
/// 解析各流 LLM 输出 → 推进阶段/写回蓝图 → 产出气泡消息。
/// 与 UI/存储/网络解耦：流式编排、SQLite 缓存、Provider、自动连续延时调度留在 VM，
/// 本类型只做确定性转换，因此可以在 Linux 上被 XCTest 完整重放验证。
public struct CreationSessionEngine {

    public var state: CreationSessionState

    public init(state: CreationSessionState) {
        self.state = state
    }

    /// 全新会话（collecting 起点）
    public init(brief: String = "", qaText: String = "") {
        self.state = CreationSessionState(phaseRaw: CreationPhase.collecting.rawValue,
                                          brief: brief, qaText: qaText,
                                          proposal: nil, blueprint: nil,
                                          volumesPerBatch: 3, chaptersPerBatch: 2,
                                          autoContinue: false)
    }

    public var phase: CreationPhase {
        CreationPhase(rawValue: state.phaseRaw) ?? .collecting
    }

    // MARK: 结算入口

    /// 流正常结束后的结算。-targetIndex 仅 chapterNames 用（目标卷下标，VM 在发起请求时记录）。
    @discardableResult
    public mutating func settle(kind: CreationStreamKind, raw: String,
                                chapterNameTargetIndex: Int = -1) -> CreationSettleOutcome {
        switch kind {
        case .clarify: return settleClarify(raw)
        case .structure: return settleStructure(raw)
        case .foundation: return settleFoundation(raw)
        case .revise: return settleRevise(raw)
        case .volumeBatch: return settleVolumeBatch(raw)
        case .chapterNames: return settleChapterNames(raw, targetIndex: chapterNameTargetIndex)
        case .chapterBatch: return settleChapterBatch(raw)
        }
    }

    /// 解析失败时界面是否需要展示原始输出（供用户检查/复制）
    public static func needsRawDisplay(_ kind: CreationStreamKind) -> Bool {
        kind != .chapterBatch && kind != .chapterNames && kind != .volumeBatch && kind != .clarify
    }

    // MARK: 各流结算

    private mutating func settleClarify(_ raw: String) -> CreationSettleOutcome {
        guard let result: ClarifyResult = LLMJSONParser.decode(ClarifyResult.self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "澄清结果解析失败，请重试")
        }
        let questions = (result.questions ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if result.enough == true || questions.isEmpty {
            // 信息足够：自动接结构规划（请求由 VM 发起）
            return outcome(message: "思路已经理清，正在规划卷章结构…", nextStep: .requestStructure)
        }
        state.qaText += "【问题】\n" + questions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n") + "\n"
        return outcome(message: "有几个地方想先确认一下：\n\n" + questions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n"))
    }

    private mutating func settleStructure(_ raw: String) -> CreationSettleOutcome {
        guard let parsed: StructureProposal = LLMJSONParser.decode(StructureProposal.self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "结构提案解析失败，可发送「重新规划」或修改意见重试")
        }
        state.proposal = parsed
        state.phaseRaw = CreationPhase.proposing.rawValue
        return outcome(message: "已按思路规划出卷章结构，请审阅下方卡片：确认结构开始生成蓝图，或直接告诉我要调整的地方。")
    }

    private mutating func settleFoundation(_ raw: String) -> CreationSettleOutcome {
        guard let parsed: NovelBlueprint = LLMJSONParser.decode(NovelBlueprint.self, fromJSONObjectIn: raw) else {
            // 蓝图解析失败回退到提案阶段：用户可重发「重新生成」或改结构
            state.phaseRaw = CreationPhase.proposing.rawValue
            return outcome(message: nil, error: "蓝图 JSON 解析失败，可发送「重新生成」")
        }
        state.blueprint = parsed
        state.phaseRaw = CreationPhase.blueprintReady.rawValue
        return outcome(message: "基础蓝图已生成（角色、世界观与卷章结构），可在卡片中审阅编辑。接下来可以：提出修改意见，或开始分批生成卷纲。")
    }

    private mutating func settleRevise(_ raw: String) -> CreationSettleOutcome {
        guard let parsed: NovelBlueprint = LLMJSONParser.decode(NovelBlueprint.self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "蓝图 JSON 解析失败，可发送「重新生成」")
        }
        state.blueprint = parsed
        return outcome(message: "已按你的意见修订蓝图，继续查看卡片或提出更多意见。")
    }

    private mutating func settleVolumeBatch(_ raw: String) -> CreationSettleOutcome {
        guard let batch: [VolumeOutlinePatch] = LLMJSONParser.decode([VolumeOutlinePatch].self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "卷纲批次解析失败，可重新生成本批")
        }
        applyVolumeBatch(batch)
        let progress = outlineProgress
        let message = progress.volumeDone >= progress.volumeTotal
            ? "卷纲已全部生成（\(progress.volumeDone)/\(progress.volumeTotal)）。可以开始分批生成细纲，或先审阅各卷卷纲。"
            : "已生成本批卷纲（进度 \(progress.volumeDone)/\(progress.volumeTotal)）。"
        let autoNext = state.autoContinue && progress.volumeDone < progress.volumeTotal
        return outcome(message: message, autoNext: autoNext)
    }

    private mutating func settleChapterNames(_ raw: String, targetIndex: Int) -> CreationSettleOutcome {
        guard var bp = state.blueprint,
              let batch: [BlueprintChapter] = LLMJSONParser.decode([BlueprintChapter].self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "章节标题解析失败，可重新生成")
        }
        guard bp.volumes.indices.contains(targetIndex) else {
            return outcome(message: "章节标题已生成完毕")
        }
        let titles = batch.compactMap { $0.title?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !titles.isEmpty else {
            return outcome(message: nil, error: "解析到空章节标题，可重新生成")
        }
        // 标题数不足时按顺序补充到本章数；多余截断
        for i in bp.volumes[targetIndex].chapters.indices {
            if i < titles.count {
                bp.volumes[targetIndex].chapters[i].title = titles[i]
            }
        }
        state.blueprint = bp
        let name = bp.volumes[targetIndex].name ?? "本卷"
        let written = min(titles.count, bp.volumes[targetIndex].chapters.count)
        return outcome(message: "已生成《\(name)》\(written) 个章节标题，可开始分批生成细纲。")
    }

    private mutating func settleChapterBatch(_ raw: String) -> CreationSettleOutcome {
        guard let batch: [BlueprintChapter] = LLMJSONParser.decode([BlueprintChapter].self, fromJSONObjectIn: raw) else {
            return outcome(message: nil, error: "细纲批次解析失败，可重新生成本批")
        }
        applyBatch(batch)
        let progress = outlineProgress
        let message = progress.outlineDone >= progress.outlineTotal
            ? "细纲已全部生成（\(progress.outlineDone)/\(progress.outlineTotal)）。点「创建作品」落库，开始写作吧！"
            : "已生成本批细纲（进度 \(progress.outlineDone)/\(progress.outlineTotal)）。"
        let autoNext = state.autoContinue && progress.outlineDone < progress.outlineTotal
        return outcome(message: message, autoNext: autoNext)
    }

    /// 用当前状态构造产出（阶段机里唯一的出口）
    private func outcome(message: String?, error: String? = nil,
                         autoNext: Bool = false, nextStep: CreationSettleOutcome.NextStep? = nil) -> CreationSettleOutcome {
        CreationSettleOutcome(state: state, message: message, error: error,
                              autoNext: autoNext, nextStep: nextStep)
    }

    // MARK: 蓝图写回（按名称/标题匹配，跳过无法定位的条目）

    /// 去除空白与常见装饰符号（冒号/书名号/引号/标点），得到可比对的规范名。
    /// 模型返回的卷名/标题常有「第一卷：雾起」「「死信」」式装饰差异，逐字相等会静默跳过。
    static func stripNameDecoration(_ name: String) -> String {
        let dropped: Set<Character> = [" ", "\t", "\n", "\r", "\u{3000}",
                                       "：", ":", "·", "、", "，", ",", "。", ".", "-", "–", "—", "…",
                                       "「", "」", "『", "』", "《", "》", "“", "”", "‘", "’",
                                       "（", "）", "(", ")", "【", "】", "[", "]", "'", "\"", "!", "！", "?", "？"]
        return String(name.lowercased().filter { !dropped.contains($0) })
    }

    /// 在候选名中定位 target：归一化精确匹配优先；退化为唯一包含匹配（有歧义不命中，宁缺勿错）。
    static func fuzzyMatchIndex(names: [String], target: String) -> Int? {
        let norm = stripNameDecoration(target)
        guard !norm.isEmpty else { return nil }
        let normNames = names.map { stripNameDecoration($0) }
        if let idx = normNames.firstIndex(where: { $0 == norm }) { return idx }
        let hits = normNames.indices.filter { idx in
            let name = normNames[idx]
            guard !name.isEmpty else { return false }
            return name.contains(norm) || norm.contains(name)
        }
        return hits.count == 1 ? hits[0] : nil
    }

    /// 把批次卷纲按卷名匹配写回蓝图对应卷（宽容匹配：归一化 + 唯一包含回退）
    public mutating func applyVolumeBatch(_ batch: [VolumeOutlinePatch]) {
        guard var bp = state.blueprint else { return }
        let names = bp.volumes.map { $0.name ?? "" }
        for item in batch {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            let outline = item.outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !outline.isEmpty else { continue }
            guard let vIndex = Self.fuzzyMatchIndex(names: names, target: name) else { continue }
            bp.volumes[vIndex].outline = item.outline
            if let arc = item.emotion_arc?.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
               !arc.isEmpty { bp.volumes[vIndex].emotion_arc = arc }
            if let ladder = item.conflict_ladder, !ladder.isEmpty {
                bp.volumes[vIndex].conflict_ladder = ladder
            }
            if let gap = item.info_gap {
                bp.volumes[vIndex].info_gap = gap
            }
        }
        state.blueprint = bp
    }

    /// 把批次细纲按标题匹配写回蓝图对应章节（宽容匹配：归一化 + 唯一包含回退，取首个命中）
    public mutating func applyBatch(_ batch: [BlueprintChapter]) {
        guard var bp = state.blueprint else { return }
        var flat: [(v: Int, c: Int, title: String)] = []
        for (v, volume) in bp.volumes.enumerated() {
            for (c, chapter) in volume.chapters.enumerated() {
                flat.append((v, c, chapter.title ?? ""))
            }
        }
        for item in batch {
            let title = item.title?.trimmingCharacters(in: .whitespaces) ?? ""
            let outline = item.detailed_outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !outline.isEmpty else { continue }
            guard let hit = Self.fuzzyMatchIndex(names: flat.map(\.title), target: title) else { continue }
            let target = flat[hit]
            bp.volumes[target.v].chapters[target.c].detailed_outline = item.detailed_outline
            if let cards = item.scene_cards, !cards.isEmpty {
                bp.volumes[target.v].chapters[target.c].scene_cards = cards
            }
            // 伏笔登记：埋设章记录 title/detail/reveal_in，揭晓章批次生成时注入提醒
            let foreshadows = (item.foreshadowings ?? []).filter {
                !($0.title ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            }
            if !foreshadows.isEmpty {
                bp.volumes[target.v].chapters[target.c].foreshadowings = foreshadows
            }
        }
        state.blueprint = bp
    }

    // MARK: 进度与批次目标选取

    public struct OutlineProgress {
        public var volumeTotal: Int
        public var volumeDone: Int
        public var outlineTotal: Int
        public var outlineDone: Int
    }

    /// 已生成/总卷数、已生成/总章数（消息进度文本与「创建作品」按钮的依据）
    public var outlineProgress: OutlineProgress {
        guard let blueprint = state.blueprint else {
            return OutlineProgress(volumeTotal: 0, volumeDone: 0, outlineTotal: 0, outlineDone: 0)
        }
        return OutlineProgress(
            volumeTotal: blueprint.volumes.count,
            volumeDone: blueprint.volumes.filter {
                !($0.outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count,
            outlineTotal: blueprint.volumes.flatMap(\.chapters).count,
            outlineDone: blueprint.volumes.flatMap(\.chapters).filter {
                !($0.detailed_outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
        )
    }

    /// 最早 N 个没有卷纲的卷名
    public func pendingVolumes(prefix: Int) -> [String] {
        guard let blueprint = state.blueprint else { return [] }
        var names: [String] = []
        for (index, volume) in blueprint.volumes.enumerated() {
            let outline = (volume.outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if outline.isEmpty {
                names.append(volume.name?.isEmpty == false ? volume.name! : "第\(index + 1)卷")
                if names.count >= prefix { return names }
            }
        }
        return names
    }

    /// 最早 N 个没有细纲的章节标题（卷序/章序）
    public func pendingChapters(prefix: Int) -> [String] {
        guard let blueprint = state.blueprint else { return [] }
        var titles: [String] = []
        for volume in blueprint.volumes {
            for chapter in volume.chapters {
                let outline = (chapter.detailed_outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if outline.isEmpty {
                    let title = chapter.title?.trimmingCharacters(in: .whitespaces) ?? ""
                    if !title.isEmpty { titles.append(title) }
                    if titles.count >= prefix { return titles }
                }
            }
        }
        return titles
    }

    /// 该卷是否缺少全部标题（生成标题按钮的显隐依据）
    public static func isEmptyVolumeTitles(_ volume: BlueprintVolume) -> Bool {
        let titles = volume.chapters.compactMap { $0.title?.trimmingCharacters(in: .whitespaces) }
        return titles.allSatisfy { $0.isEmpty } && !volume.chapters.isEmpty
    }

    // MARK: 请求上下文装配（与提示词模板的契约一一对应）

    /// 卷纲批次上下文：创意/梗概/风格/角色 + 全书结构（卷名+各卷章节数）
    /// + 已生成卷纲（承接走向） + concept（结构提案的详细思路）
    public func volumeBatchContext(targets: [String]) -> String {
        guard let blueprint = state.blueprint else { return "" }
        var lines: [String] = []
        if let title = blueprint.title_suggestion, !title.isEmpty { lines.append("【书名】\(title)") }
        if let synopsis = blueprint.synopsis, !synopsis.isEmpty { lines.append("【梗概】\(synopsis)") }
        if let style = blueprint.style_guide, !style.isEmpty { lines.append("【文风约束】\(style)") }
        if let concept = state.proposal?.concept, !concept.isEmpty {
            lines.append("【已确认的故事思路】\n\(String(concept.prefix(PromptLimits.requiredFieldCap)))")
        }
        let characters = blueprint.characters
            .compactMap { card -> String? in
                guard let name = card.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
                return "\(name)（\(card.role ?? "角色")）"
            }
        if !characters.isEmpty { lines.append("【角色】\(characters.joined(separator: "、"))") }

        // 全书结构：卷名 + 各卷章节数 + 本卷章节标题（卷纲以此为剧情范围边界）
        let structure = blueprint.volumes.enumerated().map { index, volume -> String in
            let name = volume.name?.isEmpty == false ? volume.name! : "第\(index + 1)卷"
            let isTarget = targets.contains(name)
            let titles = volume.chapters.compactMap { $0.title }.joined(separator: "、")
            var line = "◇ \(name)（\(volume.chapters.count) 章）\(isTarget ? "▶（本批）" : "")"
            if isTarget, !titles.isEmpty { line += "：\(titles)" }
            return line
        }
        lines.append("【全书结构】\n" + structure.joined(separator: "\n"))

        // 已生成卷纲（供承接）
        for volume in blueprint.volumes {
            guard let outline = volume.outline,
                  !outline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            lines.append("【\(volume.name ?? "卷")·已生成卷纲】\(outline)")
        }
        return lines.joined(separator: "\n\n")
    }

    /// 细纲批次的上下文：梗概/风格/角色 + 目标章节所在卷的卷纲 + 最近已生成细纲
    /// + 后续章节列表（衔接与伏笔揭晓定位）+ 需在本批揭晓的伏笔
    public func batchContext(targets: [String]) -> String {
        guard let blueprint = state.blueprint else { return "" }
        var lines: [String] = []
        if let title = blueprint.title_suggestion, !title.isEmpty { lines.append("【书名】\(title)") }
        if let synopsis = blueprint.synopsis, !synopsis.isEmpty { lines.append("【梗概】\(synopsis)") }
        if let style = blueprint.style_guide, !style.isEmpty { lines.append("【文风约束】\(style)") }
        if let concept = state.proposal?.concept, !concept.isEmpty {
            lines.append("【已确认的故事思路】\n\(String(concept.prefix(PromptLimits.requiredFieldCap)))")
        }
        let characters = blueprint.characters
            .compactMap { card -> String? in
                guard let name = card.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
                return "\(name)（\(card.role ?? "角色")）"
            }
        if !characters.isEmpty { lines.append("【角色】\(characters.joined(separator: "、"))") }

        // 目标章节所在卷（按标题定位第一个命中的卷）+ 各卷卷纲摘要
        for (index, volume) in blueprint.volumes.enumerated() {
            guard let outline = volume.outline, !outline.isEmpty else { continue }
            let hit = volume.chapters.contains {
                targets.contains($0.title?.trimmingCharacters(in: .whitespaces) ?? "")
            }
            if hit {
                lines.append("【\(volume.name ?? "第\(index + 1)卷")·卷纲】\(outline)")
            } else {
                lines.append("【\(volume.name ?? "第\(index + 1)卷")】\(String(outline.prefix(80)))")
            }
        }

        // 最近 5 章已生成细纲（承接走向）
        let flat = blueprint.volumes.flatMap(\.chapters)
        let generated = flat.compactMap { chapter -> String? in
            guard let outline = chapter.detailed_outline,
                  !outline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return "\(chapter.title ?? "")：\(outline)"
        }
        if !generated.isEmpty {
            lines.append("【最近已生成细纲】\n" + generated.suffix(5).joined(separator: "\n"))
        }

        // 本批之后的全部章节（衔接接口 + 伏笔揭晓章节的选择范围）
        if let lastIndex = flat.lastIndex(where: {
            targets.contains($0.title?.trimmingCharacters(in: .whitespaces) ?? "")
        }), lastIndex + 1 < flat.count {
            let upcoming = flat[(lastIndex + 1)...].compactMap { $0.title }
            if !upcoming.isEmpty {
                lines.append("【后续章节】\n" + upcoming.joined(separator: "\n"))
            }
        }

        // 之前批次埋设、且计划在本批揭晓的伏笔（提示词要求对应章必须安排回收）
        let pendingReveals = pendingForeshadows(targetTitles: targets)
        if !pendingReveals.isEmpty {
            lines.append("【需在本批揭晓的伏笔】\n" + pendingReveals.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n\n")
    }

    /// 章节标题批次的上下文
    public func chapterNamesContext(volumeName: String, count: Int) -> String {
        guard let blueprint = state.blueprint else { return "" }
        var lines: [String] = []
        if let title = blueprint.title_suggestion, !title.isEmpty { lines.append("【书名】\(title)") }
        if let synopsis = blueprint.synopsis, !synopsis.isEmpty { lines.append("【梗概】\(synopsis)") }
        if let style = blueprint.style_guide, !style.isEmpty { lines.append("【文风约束】\(style)") }
        let characters = blueprint.characters
            .compactMap { card -> String? in
                guard let name = card.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
                return "\(name)（\(card.role ?? "角色")）"
            }
        if !characters.isEmpty { lines.append("【角色】\(characters.joined(separator: "、"))") }
        if let concept = state.proposal?.concept, !concept.isEmpty {
            lines.append("【已确认的故事思路】\n\(String(concept.prefix(PromptLimits.requiredFieldCap)))")
        }
        lines.append("【目标卷】\(volumeName)（本章数：\(count)）")
        return lines.joined(separator: "\n\n")
    }

    /// 已登记伏笔中 reveal_in 命中本批章节标题的条目（渲染为提示行）
    public func pendingForeshadows(targetTitles: [String]) -> [String] {
        guard let blueprint = state.blueprint else { return [] }
        let targetSet = Set(targetTitles)
        var result: [String] = []
        for volume in blueprint.volumes {
            for chapter in volume.chapters {
                guard let planted = chapter.title else { continue }
                for fs in chapter.foreshadowings ?? [] {
                    guard let reveal = fs.reveal_in?.trimmingCharacters(in: .whitespaces),
                          targetSet.contains(reveal),
                          let title = fs.title?.trimmingCharacters(in: .whitespaces),
                          !title.isEmpty else { continue }
                    var line = "「\(title)」→ 应在《\(reveal)》揭晓（埋设于《\(planted)》）"
                    if let detail = fs.detail, !detail.isEmpty {
                        line += "：\(detail)"
                    }
                    result.append(line)
                }
            }
        }
        return result
    }

    // MARK: JSON 导出（请求上下文 / 对话修订携带）

    public func proposalJSON() -> String? {
        guard let proposal = state.proposal else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(proposal) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 供对话修订时携带当前蓝图
    public func blueprintJSON() -> String? {
        guard let blueprint = state.blueprint else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(blueprint) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: 落库映射（确认创建）

    /// 把蓝图写入数据层实体：Novel 字段 + 角色 + 世界观 + 卷/章/细纲/四维。
    /// 世界观合并而非清空——立项进行中允许手动录入条目，同名条目保留用户手输版本。
    /// 调用方负责 store.save() 与阶段置 confirmed。
    public static func applyBlueprint(_ blueprint: NovelBlueprint, into novel: Novel) {
        if let title = blueprint.title_suggestion?.trimmingCharacters(in: .whitespaces), !title.isEmpty {
            novel.title = title
        }
        if let synopsis = blueprint.synopsis?.trimmingCharacters(in: .whitespaces), !synopsis.isEmpty {
            novel.synopsis = synopsis
        }
        novel.perspective = blueprint.perspective?.isEmpty == false ? blueprint.perspective : novel.perspective
        novel.styleGuide = blueprint.style_guide?.isEmpty == false ? blueprint.style_guide : novel.styleGuide
        novel.genre = blueprint.theme?.isEmpty == false ? blueprint.theme : novel.genre
        novel.updatedAt = .now

        // 角色
        novel.characters = []
        for item in blueprint.characters {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty else { continue }
            let card = CharacterCard(name: name)
            card.appearance = item.appearance
            card.personality = item.personality
            card.currentGoal = item.goal
            if let role = item.role, !role.isEmpty {
                card.background = "书中定位：\(role)"
            }
            card.isSceneRelevant = true
            card.novel = novel
            novel.characters.append(card)
        }

        // 世界观：合并而非清空（同名条目保留用户手输版本）
        let validCategories = Set(WorldEntry.categories)
        var existingNames = Set(novel.worldEntries.map(\.name))
        for item in blueprint.worldbuilding {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty, !existingNames.contains(name) else { continue }
            let category = validCategories.contains(item.category ?? "") ? item.category! : "其他"
            let entry = WorldEntry(category: category, name: name, content: item.content ?? "")
            entry.novel = novel
            novel.worldEntries.append(entry)
            existingNames.insert(name)
        }

        // 卷与章
        novel.volumes = []
        for (volumeIndex, item) in blueprint.volumes.enumerated() {
            let volume = Volume(
                name: item.name?.isEmpty == false ? item.name! : "第\(volumeIndex + 1)卷",
                sortOrder: volumeIndex + 1,
                outline: item.outline
            )
            volume.novel = novel

            // 四维：情绪走向 / 冲突阶梯 / 信息差（可空字段，旧蓝图兼容）
            if let arc = item.emotion_arc?.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
               !arc.isEmpty {
                volume.emotionArc = arc
            }
            if let ladder = item.conflict_ladder {
                let rungs = ladder.enumerated().compactMap { index, rung -> ConflictRung? in
                    let obstacle = rung.obstacle?.trimmingCharacters(in: .whitespaces) ?? ""
                    guard !obstacle.isEmpty else { return nil }
                    return ConflictRung(level: rung.level ?? index + 1,
                                        obstacle: obstacle,
                                        turningPoint: rung.turning_point)
                }
                if !rungs.isEmpty { volume.conflictLadder = rungs }
            }
            if let gap = item.info_gap {
                let parsed = InfoGap(start: gap.start?.trimmingCharacters(in: .whitespaces) ?? "",
                                     end: gap.end?.trimmingCharacters(in: .whitespaces) ?? "")
                if !parsed.isEmpty { volume.infoGap = parsed }
            }

            for (chapterIndex, chapterItem) in item.chapters.enumerated() {
                let chapter = Chapter(
                    title: chapterItem.title?.isEmpty == false ? chapterItem.title! : "第\(chapterIndex + 1)章",
                    sortOrder: chapterIndex + 1
                )
                let outline = chapterItem.detailed_outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                chapter.detailedOutline = outline.isEmpty ? nil : outline

                // 场景卡：三要素全空的丢弃
                let cards = (chapterItem.scene_cards ?? []).map { card in
                    SceneCard(goal: card.goal ?? "", obstacle: card.obstacle ?? "", hook: card.hook ?? "")
                }.filter { !$0.isEmpty }
                if !cards.isEmpty { chapter.sceneCards = cards }

                chapter.volume = volume
                volume.chapters.append(chapter)
            }
            novel.volumes.append(volume)
        }
    }
}

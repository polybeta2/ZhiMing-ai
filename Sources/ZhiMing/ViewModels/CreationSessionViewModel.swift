#if os(iOS) || os(macOS)
import Foundation
import Combine
import ZhiMingCore

// MARK: - 立项会话状态机

/// 分阶段立项：collecting（澄清循环）→ proposing（结构提案）→
/// blueprintReady（基础蓝图）→ outlining（细纲分批，可自动连续）→ confirmed
/// iOS 15 兼容：ObservableObject + @Published
@MainActor
final class CreationSessionViewModel: ObservableObject {
    /// String 原始值用于 SQLite 快照恢复（phase 持久化）
    enum Phase: String, Codable, Equatable { case collecting, proposing, blueprintReady, outlining, confirmed }
    enum StreamKind { case clarify, structure, foundation, revise, volumeBatch, chapterBatch, chapterNames }

    @Published private(set) var phase: Phase = .collecting
    @Published private(set) var isStreaming = false
    @Published var blueprint: NovelBlueprint?
    @Published private(set) var proposal: StructureProposal?
    /// 原始流式输出（JSON）：流结束后即清空，界面只做统计展示
    @Published private(set) var draft = ""
    @Published var errorMessage: String?
    /// 卷纲进度：已生成 / 总卷数
    @Published private(set) var volumeDone = 0
    @Published private(set) var volumeTotal = 0
    /// 细纲进度：已生成 / 总章数
    @Published private(set) var outlineDone = 0
    @Published private(set) var outlineTotal = 0
    /// 每轮生成的卷数（1~5）与章数（1~3），共用自动连续开关
    @Published var volumesPerBatch = 3
    @Published var chaptersPerBatch = 2
    @Published var autoContinue = false
    /// 流式过程可视化（等待首Token/深度思考/输出统计）
    let progress = StreamProgressTracker()

    /// 流结束回调：kind + 预备好的助手消息（追加气泡用，nil 不追加）+ raw（解析失败时界面展示）
    var onStreamSettled: ((_ kind: StreamKind, _ message: String?, _ raw: String, _ parsed: Bool) -> Void)?
    private var streamTask: Task<Void, Never>?

    private var provider: ProviderConfig?
    private var supplement: String?
    private var brief = ""          // 初始创意
    private var qaText = ""         // 澄清问答累积文本
    /// SQLite 缓存键（对应 ChatThread.id）；nil = 未接缓存（不落盘）
    private var cacheKey: UUID?

    /// 注入当前提供商：发消息/恢复会话后设置；provider 不入缓存（含 Keychain 引用），
    /// 退出重进后必须重新注入，否则 confirmProposal/sendProposalFeedback 的 guard 会短路
    func setProvider(_ provider: ProviderConfig?) {
        self.provider = provider
    }

    // MARK: 会话缓存（SQLite）

    /// 绑定缓存键并尝试恢复上次进度（nil/无记录/损坏时静默保持空会话）
    func attachAndRestore(threadID: UUID) {
        cacheKey = threadID
        guard let payload = CreationSessionCache.load(forThread: threadID),
              let data = payload.data(using: .utf8),
              let state = try? JSONDecoder().decode(CreationSessionState.self, from: data),
              let restored = CreationSessionViewModel.Phase(rawValue: state.phaseRaw),
              restored != .confirmed else { return }
        phase = restored
        brief = state.brief
        qaText = state.qaText
        proposal = state.proposal
        blueprint = state.blueprint
        volumesPerBatch = state.volumesPerBatch
        chaptersPerBatch = state.chaptersPerBatch
        autoContinue = false        // 恢复会话不自动续跑，由用户手动触发
        refreshOutlineProgress()
    }

    /// 把当前流程状态写入 SQLite 缓存（静默；失败不影响主流程）
    func persist() {
        guard let cacheKey else { return }
        let state = CreationSessionState(
            phaseRaw: phase.rawValue,
            brief: brief,
            qaText: qaText,
            proposal: proposal,
            blueprint: blueprint,
            volumesPerBatch: volumesPerBatch,
            chaptersPerBatch: chaptersPerBatch,
            autoContinue: autoContinue
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state),
              let payload = String(data: data, encoding: .utf8) else { return }
        CreationSessionCache.save(payload: payload, forThread: cacheKey)
    }

    /// 会话终结（作品已创建）：清除缓存并脱离绑定
    private func detachCache() {
        guard let cacheKey else { return }
        CreationSessionCache.remove(forThread: cacheKey)
        self.cacheKey = nil
    }

    // MARK: 阶段 1：澄清提问（collecting）

    /// brief 是否尚未填充（供界面路由判断：完整思路首次启动 or 重试）
    var briefIsEmpty: Bool { brief.isEmpty }

    /// 用户在 collecting 发送消息：首条为创意，其余为对问题的回答
    func sendCollecting(text: String, provider: ProviderConfig, supplement: String?) {
        if brief.isEmpty {
            brief = text
        } else {
            qaText += "【回答】\(text)\n"
        }
        self.provider = provider
        self.supplement = supplement
        persist()       // 创意/回答先落盘，防中途退出丢上下文
        requestClarify()
    }

    /// 完整思路立项：跳过澄清问答，直接规划卷章结构。
    /// brief 已存在时为重试语义（如结构解析失败后发「重新生成」），忽略新文本；
    /// 用户想补充思路 → 等结构提案卡出现后走「修改意见」（proposing 流程）。
    func sendFullIdea(text: String, provider: ProviderConfig, supplement: String?) {
        if brief.isEmpty { brief = text }
        self.provider = provider
        self.supplement = supplement
        persist()
        requestStructure(feedback: nil)
    }

    private func requestClarify() {
        guard let provider else { return }
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationClarify(brief: brief, qaHistory: qaText, supplement: supplement)
        )
        beginStream(kind: .clarify, messages: messages, provider: provider)
    }

    // MARK: 阶段 2：结构提案（proposing）

    /// 确认结构 → 生成基础蓝图
    func confirmProposal() {
        requestFoundation(feedback: nil)
    }

    /// 结构提案阶段的修改意见 → 重新规划
    func sendProposalFeedback(_ feedback: String) {
        guard provider != nil else { return }
        requestStructure(feedback: feedback)
    }

    private func requestStructure(feedback: String?) {
        guard let provider else { return }
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationStructure(
                brief: brief, qaHistory: qaText, feedback: feedback, supplement: supplement)
        )
        beginStream(kind: .structure, messages: messages, provider: provider)
    }

    // MARK: 阶段 3：基础蓝图（blueprintReady）

    private func requestFoundation(feedback: String?) {
        guard let provider else { return }
        let structureJSON = proposalJSON() ?? "{}"
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationFoundation(
                brief: brief, qaHistory: qaText, structureJSON: structureJSON,
                feedback: feedback, supplement: supplement)
        )
        beginStream(kind: .foundation, messages: messages, provider: provider)
    }

    // MARK: 对话修订（blueprintReady / outlining）

    func revise(feedback: String, provider: ProviderConfig, supplement: String? = nil) {
        guard let json = blueprintJSON() else {
            errorMessage = "当前没有可修订的蓝图"
            return
        }
        self.provider = provider
        self.supplement = supplement
        // 修订期间暂停自动连续
        autoContinue = false
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationRevise(blueprintJSON: json, feedback: feedback, supplement: supplement)
        )
        beginStream(kind: .revise, messages: messages, provider: provider)
    }

    // MARK: 阶段 4：卷纲分批（blueprintReady 内）

    /// 卷纲是否还有缺口（foundation 生成的蓝图卷纲留空，由本批次补齐）
    var volumePendingCount: Int { max(0, volumeTotal - volumeDone) }

    /// 生成下一批卷纲（按 volumesPerBatch 取最早未生成的卷）
    func generateNextVolumeBatch() {
        guard let provider, blueprint != nil, !isStreaming else { return }
        let targets = pendingVolumes(prefix: volumesPerBatch)
        guard !targets.isEmpty else { return }
        let context = volumeBatchContext(targets: targets)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationVolumeBatch(context: context, targets: targets, supplement: supplement)
        )
        beginStream(kind: .volumeBatch, messages: messages, provider: provider)
    }

    /// 最早 N 个没有卷纲的卷名
    private func pendingVolumes(prefix: Int) -> [String] {
        guard let blueprint else { return [] }
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

    /// 卷纲批次上下文：创意/梗概/风格/角色 + 全书结构（卷名+各卷章节数）
    /// + 已生成卷纲（承接走向） + concept（结构提案的详细思路）
    private func volumeBatchContext(targets: [String]) -> String {
        guard let blueprint else { return "" }
        var lines: [String] = []
        if let title = blueprint.title_suggestion, !title.isEmpty { lines.append("【书名】\(title)") }
        if let synopsis = blueprint.synopsis, !synopsis.isEmpty { lines.append("【梗概】\(synopsis)") }
        if let style = blueprint.style_guide, !style.isEmpty { lines.append("【文风约束】\(style)") }
        if let concept = proposal?.concept, !concept.isEmpty {
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

        // 已生成卷纲（供承接；只给全量给本批前一卷，其余给摘要行）
        for volume in blueprint.volumes {
            guard let outline = volume.outline,
                  !outline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            lines.append("【\(volume.name ?? "卷")·已生成卷纲】\(outline)")
        }
        return lines.joined(separator: "\n\n")
    }

    /// 把批次卷纲按卷名匹配写回蓝图对应卷
    private func applyVolumeBatch(_ batch: [VolumeOutlinePatch]) {
        guard var bp = blueprint else { return }
        for item in batch {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            let outline = item.outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !outline.isEmpty else { continue }
            guard let vIndex = bp.volumes.firstIndex(where: {
                ($0.name ?? "").trimmingCharacters(in: .whitespaces) == name
            }) else { continue }
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
        blueprint = bp
    }

    // MARK: 阶段 5：细纲分批（outlining）

    /// 开始细纲阶段（卷纲补齐或用户跳过时进入）
    func startOutlining() {
        guard blueprint != nil else { return }
        refreshOutlineProgress()
        phase = .outlining
    }

    /// 生成下一批细纲（按 chaptersPerBatch 取最早未生成的章节）
    func generateNextBatch() {
        guard let provider, blueprint != nil, !isStreaming else { return }
        let targets = pendingChapters(prefix: chaptersPerBatch)
        guard !targets.isEmpty else { return }
        if phase != .outlining { startOutlining() }
        let context = batchContext(targets: targets)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationChapterBatch(context: context, targets: targets, supplement: supplement)
        )
        beginStream(kind: .chapterBatch, messages: messages, provider: provider)
    }

    // MARK: 章节标题批次（长篇小说蓝图补全）

    /// 为指定卷生成全部章节标题（仅当该卷 chapters 全无标题时可用，见 isEmptyVolumeTitles）
    func generateChapterNames(volumeIndex: Int) {
        guard let provider, !isStreaming, let blueprint else { return }
        guard blueprint.volumes.indices.contains(volumeIndex) else { return }
        let volume = blueprint.volumes[volumeIndex]
        guard isEmptyVolumeTitles(volume) else { return }
        let context = chapterNamesContext(volumeName: volume.name ?? "第\(volumeIndex + 1)卷",
                                          count: volume.chapters.count)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationChapterNames(context: context, supplement: supplement)
        )
        chapterNameTargetIndex = volumeIndex
        beginStream(kind: .chapterNames, messages: messages, provider: provider)
    }

    /// 该卷是否缺少全部标题（生成标题按钮的显隐依据）
    func isEmptyVolumeTitles(_ volume: BlueprintVolume) -> Bool {
        let titles = volume.chapters.compactMap { $0.title?.trimmingCharacters(in: .whitespaces) }
        return titles.allSatisfy { $0.isEmpty } && !volume.chapters.isEmpty
    }

    /// 本轮章节标题的目标卷（settle 写回用）
    private var chapterNameTargetIndex = -1

    private func chapterNamesContext(volumeName: String, count: Int) -> String {
        guard let blueprint else { return "" }
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
        if let concept = proposal?.concept, !concept.isEmpty {
            lines.append("【已确认的故事思路】\n\(String(concept.prefix(PromptLimits.requiredFieldCap)))")
        }
        lines.append("【目标卷】\(volumeName)（本章数：\(count)）")
        return lines.joined(separator: "\n\n")
    }

    func stop() {
        autoContinue = false
        streamTask?.cancel()
    }

    /// 已生成/总卷数、已生成/总章数
    private func refreshOutlineProgress() {
        guard let blueprint else { return }
        volumeTotal = blueprint.volumes.count
        volumeDone = blueprint.volumes.filter {
            !($0.outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let all = blueprint.volumes.flatMap(\.chapters)
        outlineTotal = all.count
        outlineDone = all.filter { !($0.detailed_outline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    /// 最早 N 个没有细纲的章节标题（卷序/章序）
    private func pendingChapters(prefix: Int) -> [String] {
        guard let blueprint else { return [] }
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

    /// 细纲批次的上下文：梗概/风格/角色 + 目标章节所在卷的卷纲 + 最近已生成细纲
    /// + 后续章节列表（衔接与伏笔揭晓定位）+ 需在本批揭晓的伏笔
    private func batchContext(targets: [String]) -> String {
        guard let blueprint else { return "" }
        var lines: [String] = []
        if let title = blueprint.title_suggestion, !title.isEmpty { lines.append("【书名】\(title)") }
        if let synopsis = blueprint.synopsis, !synopsis.isEmpty { lines.append("【梗概】\(synopsis)") }
        if let style = blueprint.style_guide, !style.isEmpty { lines.append("【文风约束】\(style)") }
        if let concept = proposal?.concept, !concept.isEmpty {
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

    /// 已登记伏笔中 reveal_in 命中本批章节标题的条目（渲染为提示行）
    private func pendingForeshadows(targetTitles: [String]) -> [String] {
        guard let blueprint else { return [] }
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

    // MARK: 确认创建

    /// 把蓝图写入数据层：Novel + 角色 + 世界观 + 卷/章/细纲
    func confirm(into novel: Novel, store: AppStore) {
        guard let blueprint else { return }

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

        // 世界观：合并而非清空——立项进行中允许手动录入条目，
        // 置空会在确认蓝图时静默丢失它们（同名条目保留用户手输版本）
        let validCategories = Set(WorldListView.categories)
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

        autoContinue = false
        phase = .confirmed
        store.save()
        detachCache()   // 作品已落库，立项会话缓存使命完成
    }

    // MARK: 内部

    /// 供对话修订时携带当前蓝图
    func blueprintJSON() -> String? {
        guard let blueprint else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(blueprint) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func proposalJSON() -> String? {
        guard let proposal else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(proposal) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 体量护栏（v1.7）：超过告警线的请求先弹确认，确认通过才进入流式状态
    private func beginStream(kind: StreamKind, messages: [LLMMessage], provider: ProviderConfig) {
        guard !isStreaming else { return }
        let totalChars = messages.totalContentChars
        Task { @MainActor in
            guard await PromptGuard.authorized(totalChars: totalChars) else { return }
            self.isStreaming = true
            self.draft = ""
            self.errorMessage = nil
            self.persist()      // 流开始前记录本轮请求的上下文（批量参数/开关等）
            KeepAwake.set(true)
            self.stream(kind: kind, messages: messages, provider: provider)
        }
    }

    private func stream(kind: StreamKind, messages: [LLMMessage], provider: ProviderConfig) {
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            isStreaming = false
            return
        }
        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        streamTask?.cancel()
        streamTask = Task {
            var raw = ""
            progress.begin()
            do {
                for try await event in client.streamChat(messages: messages, config: config) {
                    progress.handle(event)
                    if case .content(let delta) = event { raw += delta }
                }
                if !Task.isCancelled {
                    let message = self.settle(kind: kind, raw: raw)
                    self.onStreamSettled?(kind, message, raw, message != nil || kindNeedsRaw(kind))
                }
            } catch is CancellationError {
                // 停止：保留已生成部分给界面展示
                self.errorMessage = raw.isEmpty ? nil : "生成被停止，已保留部分结果"
                self.draft = ""
                self.onStreamSettled?(kind, nil, raw, false)
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.onStreamSettled?(kind, nil, "", false)
                }
            }
            self.draft = ""
            self.progress.finish()
            self.persist()      // 流结束：settle 已改 phase/蓝图，落盘保存最新进度
            self.isStreaming = false
            KeepAwake.set(false)
        }
    }

    /// 解析失败时界面是否需要展示原始输出
    private func kindNeedsRaw(_ kind: StreamKind) -> Bool {
        kind != .chapterBatch && kind != .chapterNames && kind != .volumeBatch && kind != .clarify
    }

    /// 流正常结束：解析并驱动阶段转换，返回给界面的助手消息（nil 不追加）
    @discardableResult
    private func settle(kind: StreamKind, raw: String) -> String? {
        switch kind {
        case .clarify:
            guard let result = LLMJSONParser.decode(ClarifyResult.self, fromJSONObjectIn: raw) else {
                errorMessage = "澄清结果解析失败，请重试"
                return nil
            }
            let questions = (result.questions ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if result.enough == true || questions.isEmpty {
                // 信息足够：自动接结构规划
                Task { @MainActor in
                    self.requestStructure(feedback: nil)
                }
                return "思路已经理清，正在规划卷章结构…"
            }
            qaText += "【问题】\n" + questions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n") + "\n"
            return "有几个地方想先确认一下：\n\n" + questions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        case .structure:
            guard let parsed = LLMJSONParser.decode(StructureProposal.self, fromJSONObjectIn: raw) else {
                errorMessage = "结构提案解析失败，可发送「重新规划」或修改意见重试"
                return nil
            }
            proposal = parsed
            phase = .proposing
            return "已按思路规划出卷章结构，请审阅下方卡片：确认结构开始生成蓝图，或直接告诉我要调整的地方。"
        case .foundation:
            guard let parsed = LLMJSONParser.decode(NovelBlueprint.self, fromJSONObjectIn: raw) else {
                errorMessage = "蓝图 JSON 解析失败，可发送「重新生成」"
                phase = .proposing
                return nil
            }
            blueprint = parsed
            refreshOutlineProgress()
            phase = .blueprintReady
            return "基础蓝图已生成（角色、世界观与卷章结构），可在卡片中审阅编辑。接下来可以：提出修改意见，或开始分批生成卷纲。"
        case .revise:
            guard let parsed = LLMJSONParser.decode(NovelBlueprint.self, fromJSONObjectIn: raw) else {
                errorMessage = "蓝图 JSON 解析失败，可发送「重新生成」"
                return nil
            }
            blueprint = parsed
            refreshOutlineProgress()
            return "已按你的意见修订蓝图，继续查看卡片或提出更多意见。"
        case .volumeBatch:
            guard let batch = LLMJSONParser.decode([VolumeOutlinePatch].self, fromJSONObjectIn: raw) else {
                errorMessage = "卷纲批次解析失败，可重新生成本批"
                return nil
            }
            applyVolumeBatch(batch)
            refreshOutlineProgress()
            let done = volumeDone, total = volumeTotal
            let message = done >= total
                ? "卷纲已全部生成（\(done)/\(total)）。可以开始分批生成细纲，或先审阅各卷卷纲。"
                : "已生成本批卷纲（进度 \(done)/\(total)）。"
            // 自动连续：还有剩余卷且开关开启 → 延迟接下一批卷纲
            if autoContinue, done < total {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard self.autoContinue, !self.isStreaming, self.volumeDone < self.volumeTotal else { return }
                    self.generateNextVolumeBatch()
                }
            }
            return message
        case .chapterNames:
            // 章节标题批次：写回目标卷的 chapters title（保持空细纲待生成状态）
            guard let batch = LLMJSONParser.decode([BlueprintChapter].self, fromJSONObjectIn: raw),
                  blueprint != nil else {
                errorMessage = "章节标题解析失败，可重新生成"
                return nil
            }
            var bp = blueprint!
            let vIndex = chapterNameTargetIndex
            guard bp.volumes.indices.contains(vIndex) else { return "章节标题已生成完毕" }
            let titles = batch.compactMap { $0.title?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !titles.isEmpty else {
                errorMessage = "解析到空章节标题，可重新生成"
                return nil
            }
            // 标题数不足时按顺序补充到本章数；多余截断
            for i in bp.volumes[vIndex].chapters.indices {
                if i < titles.count {
                    bp.volumes[vIndex].chapters[i].title = titles[i]
                }
            }
            blueprint = bp
            refreshOutlineProgress()
            return "已生成《\(bp.volumes[vIndex].name ?? "本卷")》\(min(titles.count, bp.volumes[vIndex].chapters.count)) 个章节标题，可开始分批生成细纲。"
        case .chapterBatch:
            guard let batch = LLMJSONParser.decode([BlueprintChapter].self, fromJSONObjectIn: raw) else {
                errorMessage = "细纲批次解析失败，可重新生成本批"
                return nil
            }
            applyBatch(batch)
            refreshOutlineProgress()
            let done = outlineDone, total = outlineTotal
            let message = done >= total
                ? "细纲已全部生成（\(done)/\(total)）。点「创建作品」落库，开始写作吧！"
                : "已生成本批细纲（进度 \(done)/\(total)）。"
            // 自动连续：还有剩余且开关开启 → 延迟接下一批
            if autoContinue, done < total {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard self.autoContinue, !self.isStreaming, self.outlineDone < self.outlineTotal else { return }
                    self.generateNextBatch()
                }
            }
            return message
        }
    }

    /// 把批次细纲按标题匹配写回蓝图对应章节
    private func applyBatch(_ batch: [BlueprintChapter]) {
        guard var bp = blueprint else { return }
        for item in batch {
            let title = item.title?.trimmingCharacters(in: .whitespaces) ?? ""
            let outline = item.detailed_outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !outline.isEmpty else { continue }
            outer: for vIndex in bp.volumes.indices {
                for cIndex in bp.volumes[vIndex].chapters.indices {
                    let chapter = bp.volumes[vIndex].chapters[cIndex]
                    if chapter.title?.trimmingCharacters(in: .whitespaces) == title {
                        bp.volumes[vIndex].chapters[cIndex].detailed_outline = item.detailed_outline
                        if let cards = item.scene_cards, !cards.isEmpty {
                            bp.volumes[vIndex].chapters[cIndex].scene_cards = cards
                        }
                        // 伏笔登记：埋设章记录 title/detail/reveal_in，揭晓章批次生成时注入提醒
                        let foreshadows = (item.foreshadowings ?? []).filter {
                            !($0.title ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                        }
                        if !foreshadows.isEmpty {
                            bp.volumes[vIndex].chapters[cIndex].foreshadowings = foreshadows
                        }
                        break outer
                    }
                }
            }
        }
        blueprint = bp
    }
}
#endif

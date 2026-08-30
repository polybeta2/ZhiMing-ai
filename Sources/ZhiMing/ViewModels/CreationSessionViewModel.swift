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
    /// 阶段与流类别随状态机核心下沉 ZhiMingCore（见 CreationSessionEngine）
    typealias Phase = CreationPhase
    typealias StreamKind = CreationStreamKind

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

    /// 同人注入器：(目标串, 预算) → 原作时间窗文本（target=nil 时返回全书梗概）。
    /// 由宿主（ChatView）注入闭包，闭包内经 store 查 novel.sourceProfileID 渲染。
    var sourceWindowProvider: ((_ target: String?, _ maxChars: Int) -> String?)?

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
        applyEngineState(state)
        autoContinue = false        // 恢复会话不自动续跑，由用户手动触发
        refreshOutlineProgress()
    }

    /// 把当前流程状态写入 SQLite 缓存（静默；失败不影响主流程）
    func persist() {
        guard let cacheKey else { return }
        let state = engineState()
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
            to: PromptTemplates.creationClarify(
                brief: brief, qaHistory: qaText, supplement: supplement,
                sourceContext: sourceWindowProvider?(nil, 4000))
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
                brief: brief, qaHistory: qaText, feedback: feedback, supplement: supplement,
                sourceContext: sourceWindowProvider?(nil, 8000))
        )
        beginStream(kind: .structure, messages: messages, provider: provider)
    }

    // MARK: 阶段 3：基础蓝图（blueprintReady）

    private func requestFoundation(feedback: String?) {
        guard let provider else { return }
        let structureJSON = CreationSessionEngine(state: engineState()).proposalJSON() ?? "{}"
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationFoundation(
                brief: brief, qaHistory: qaText, structureJSON: structureJSON,
                feedback: feedback, supplement: supplement,
                sourceContext: sourceWindowProvider?(nil, 8000))
        )
        beginStream(kind: .foundation, messages: messages, provider: provider)
    }

    // MARK: 对话修订（blueprintReady / outlining）

    func revise(feedback: String, provider: ProviderConfig, supplement: String? = nil) {
        guard let json = CreationSessionEngine(state: engineState()).blueprintJSON() else {
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
        let engine = CreationSessionEngine(state: engineState())
        let targets = engine.pendingVolumes(prefix: volumesPerBatch)
        guard !targets.isEmpty else { return }
        let context = engine.volumeBatchContext(
            targets: targets,
            sourceWindow: sourceWindowProvider?(targets.first, 6000))
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationVolumeBatch(context: context, targets: targets, supplement: supplement)
        )
        beginStream(kind: .volumeBatch, messages: messages, provider: provider)
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
        let engine = CreationSessionEngine(state: engineState())
        let targets = engine.pendingChapters(prefix: chaptersPerBatch)
        guard !targets.isEmpty else { return }
        if phase != .outlining { startOutlining() }
        let context = engine.batchContext(
            targets: targets,
            sourceWindow: sourceWindowProvider?(targets.first, 4000))
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
        guard CreationSessionEngine.isEmptyVolumeTitles(volume) else { return }
        let context = CreationSessionEngine(state: engineState())
            .chapterNamesContext(volumeName: volume.name ?? "第\(volumeIndex + 1)卷",
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
        CreationSessionEngine.isEmptyVolumeTitles(volume)
    }

    /// 本轮章节标题的目标卷（settle 写回用）
    private var chapterNameTargetIndex = -1

    func stop() {
        autoContinue = false
        streamTask?.cancel()
    }

    /// 已生成/总卷数、已生成/总章数（引擎计算，镜像到 @Published 供界面展示）
    private func refreshOutlineProgress() {
        guard blueprint != nil else { return }
        let progress = CreationSessionEngine(state: engineState()).outlineProgress
        volumeTotal = progress.volumeTotal
        volumeDone = progress.volumeDone
        outlineTotal = progress.outlineTotal
        outlineDone = progress.outlineDone
    }

    // MARK: 确认创建

    /// 把蓝图写入数据层：Novel + 角色 + 世界观 + 卷/章/细纲
    func confirm(into novel: Novel, store: AppStore) {
        guard let blueprint else { return }
        CreationSessionEngine.applyBlueprint(blueprint, into: novel)
        autoContinue = false
        phase = .confirmed
        store.save()
        detachCache()   // 作品已落库，立项会话缓存使命完成
    }

    // MARK: 内部

    // MARK: 状态机核心桥接（唯一事实源是本类的 @Published 镜像）

    /// 从镜像字段构建引擎状态
    private func engineState() -> CreationSessionState {
        CreationSessionState(phaseRaw: phase.rawValue, brief: brief, qaText: qaText,
                             proposal: proposal, blueprint: blueprint,
                             volumesPerBatch: volumesPerBatch, chaptersPerBatch: chaptersPerBatch,
                             autoContinue: autoContinue)
    }

    /// 把引擎结算后的状态写回镜像
    private func applyEngineState(_ state: CreationSessionState) {
        phase = CreationPhase(rawValue: state.phaseRaw) ?? phase
        brief = state.brief
        qaText = state.qaText
        proposal = state.proposal
        blueprint = state.blueprint
        volumesPerBatch = state.volumesPerBatch
        chaptersPerBatch = state.chaptersPerBatch
        autoContinue = state.autoContinue
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
                    self.onStreamSettled?(kind, message, raw, message != nil || CreationSessionEngine.needsRawDisplay(kind))
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

    /// 流正常结束：解析并驱动阶段转换，返回给界面的助手消息（nil 不追加）。
    /// 解析/转换在 ZhiMingCore 的 CreationSessionEngine（Linux 可测），本方法只做镜像同步与调度。
    @discardableResult
    private func settle(kind: StreamKind, raw: String) -> String? {
        var engine = CreationSessionEngine(state: engineState())
        let result = engine.settle(kind: kind, raw: raw, chapterNameTargetIndex: chapterNameTargetIndex)
        applyEngineState(result.state)
        if let error = result.error { errorMessage = error }
        if case .requestStructure? = result.nextStep {
            Task { @MainActor in self.requestStructure(feedback: nil) }
        }
        if result.autoNext {
            // 自动连续：还有剩余且开关开启 → 延迟接下一批
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard self.autoContinue, !self.isStreaming else { return }
                if kind == .volumeBatch, self.volumeDone < self.volumeTotal {
                    self.generateNextVolumeBatch()
                }
                if kind == .chapterBatch, self.outlineDone < self.outlineTotal {
                    self.generateNextBatch()
                }
            }
        }
        return result.message
    }
}
#endif

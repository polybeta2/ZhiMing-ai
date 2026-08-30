#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 通用聊天页（立项与写作助手共用）
/// 立项：分阶段共创（澄清提问 → 结构提案 → 基础蓝图 → 细纲分批 → 创建作品）
/// 能力：消息持久化到 ChatThread、流式状态可视化、停止、重发最后一条、会话内切换模型
struct ChatView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel
    @ObservedObject var thread: ChatThread

    @State private var input = ""
    @State private var isStreaming = false
    @State private var streamingText = ""
    @State private var streamTask: Task<Void, Never>?
    @State private var showModelSelector = false
    @State private var sessionProvider: ProviderConfig?
    @StateObject private var creation = CreationSessionViewModel()
    @StateObject private var assistantProgress = StreamProgressTracker()
    @State private var writingError: String?
    @State private var appeared = false

    /// 助手权限：只读=仅建议；读写=可提议补丁，经用户确认后写入设定（仅写作助手生效）
    @AppStorage("assistant.accessMode") private var accessModeRaw = AssistantAccessMode.readOnly.rawValue
    @State private var pendingPatch: AssistantPatch?
    @State private var appliedNotice: String?

    private var isCreation: Bool { thread.purpose == "creation" }
    private var activeProvider: ProviderConfig? { sessionProvider ?? store.defaultProvider }
    private var currentModelName: String {
        activeProvider?.modelName ?? "未配置"
    }
    /// 任一流式进行中（含立项 VM 的流）
    private var anyStreaming: Bool { isStreaming || creation.isStreaming }

    private var accessMode: AssistantAccessMode {
        AssistantAccessMode(rawValue: accessModeRaw) ?? .readOnly
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if !isCreation, let patch = pendingPatch {
                PatchProposalCard(
                    summary: patch.summary,
                    lines: patch.describe(novel: novel),
                    onApply: { applyPatch(patch) },
                    onIgnore: { pendingPatch = nil }
                )
                .padding(.horizontal, AppTheme.spacing[2])
                .padding(.vertical, AppTheme.spacing[1])
            }
            if isCreation {
                creationActions
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let banner = bannerText {
                    Label(banner, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.spacing[3])
                        .padding(.top, AppTheme.spacing[1])
                        .background(.bar)
                }
                if !isCreation {
                    // 写作助手权限：显式分段开关，比 toolbar 里的锁菜单更易发现与调整
                    HStack(spacing: AppTheme.spacing[2]) {
                        Text("可编辑设定")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("写作助手权限", selection: Binding(
                            get: { accessMode },
                            set: { accessModeRaw = $0.rawValue }
                        )) {
                            Text("只读").tag(AssistantAccessMode.readOnly)
                            Text("读写").tag(AssistantAccessMode.readWrite)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                    .padding(.horizontal, AppTheme.spacing[3])
                    .padding(.vertical, AppTheme.spacing[1])
                    .background(.bar)
                }
                ChatInputBar(
                    text: $input,
                    isStreaming: anyStreaming,
                    placeholder: isCreation ? "输入创意或回答问题…" : "向写作助手提问…",
                    onSend: sendCurrentInput,
                    onStop: stopStreaming
                )
            }
        }
        .navigationTitle(isCreation ? "立项助手" : "写作助手")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppTheme.spacing[2]) {
                    // 助手权限切换（仅写作助手；立项流程不受影响）
                    if !isCreation {
                        Menu {
                            Picker("助手权限", selection: Binding(
                                get: { accessMode },
                                set: { accessModeRaw = $0.rawValue }
                            )) {
                                Text("只读 · 仅建议").tag(AssistantAccessMode.readOnly)
                                Text("读写 · 经确认可改设定").tag(AssistantAccessMode.readWrite)
                            }
                        } label: {
                            Image(systemName: accessMode == .readWrite ? "lock.open.fill" : "lock.fill")
                        }
                    }
                    Button {
                        resendLastUserMessage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(anyStreaming || lastUserMessage == nil)

                    Button {
                        showModelSelector = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(currentModelName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 90)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.zmPress)
                }
            }
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorSheet(selection: $sessionProvider)
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            creation.onStreamSettled = { kind, message, raw, parsed in
                settleCreation(kind: kind, message: message, raw: raw, parsed: parsed)
            }
            // 同人注入：从书库解析 novel 绑定的原作档案，按目标串渲染时间窗
            creation.sourceWindowProvider = { target, maxChars in
                if let target, !target.isEmpty {
                    return SourceScanInjection.sourceWindow(
                        novel: novel, profiles: store.sourceProfiles, target: target, maxChars: maxChars)
                }
                return SourceScanInjection.sourceContext(
                    novel: novel, profiles: store.sourceProfiles, maxChars: maxChars)
            }
            if isCreation {
                // 恢复上次进度（SQLite）：阶段/问答/提案/蓝图原样回来，AI上下文不丢失
                creation.attachAndRestore(threadID: thread.id)
                // provider 不入缓存：恢复后重新注入，否则确认结构/发送消息的 guard 会短路
                creation.setProvider(activeProvider)
                // 完整思路立项：跳过澄清，进入对话即自动规划卷章结构
                if thread.skipsClarification, creation.phase == .collecting,
                   thread.messages.isEmpty, !novel.synopsis.isEmpty {
                    if let provider = activeProvider {
                        appendAssistant("已收到你的完整思路，正在直接规划卷章结构…")
                        let userMessage = ChatMessage(role: "user", content: novel.synopsis)
                        userMessage.thread = thread
                        thread.messages.append(userMessage)
                        creation.sendFullIdea(text: novel.synopsis, provider: provider,
                                              supplement: fullIdeaSupplement())
                        store.save()
                    }
                } else if creation.phase == .collecting, thread.messages.isEmpty,
                          input.isEmpty, !novel.synopsis.isEmpty {
                    input = novel.synopsis
                }
            }
        }
        .onDisappear {
            streamTask?.cancel()
            creation.stop()
            creation.persist()   // 兜底：退出页面时把最新进度落盘
        }
        .alert("已应用设定修改", isPresented: Binding(
            get: { appliedNotice != nil },
            set: { if !$0 { appliedNotice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(appliedNotice ?? "")
        }
    }

    private var bannerText: String? {
        if isCreation { return creation.errorMessage }
        return writingError
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.spacing[2]) {
                    if thread.messages.isEmpty && !anyStreaming {
                        emptyHint
                    }
                    ForEach(thread.messages) { message in
                        MessageBubbleView(role: message.role, text: message.content)
                            .id(message.id)
                    }
                    // 写作助手流式：等待/思考阶段显示状态行，输出阶段恢复文本气泡
                    if isStreaming {
                        if assistantProgress.stage == .outputting {
                            MessageBubbleView(role: "assistant", text: streamingText, isStreaming: true)
                                .id("streaming")
                        } else {
                            StreamingStatusView(tracker: assistantProgress, showsOutputting: false)
                                .id("streaming")
                        }
                    }
                    // 立项流式：JSON 不直接显示，只展示统计状态
                    if isCreation, creation.isStreaming {
                        StreamingStatusView(tracker: creation.progress)
                            .id("creationStreaming")
                    }
                    if isCreation, creation.phase == .proposing, creation.proposal != nil {
                        StructureProposalCard(vm: creation)
                            .id("proposal")
                    }
                    if isCreation, creation.blueprint != nil,
                       creation.phase == .blueprintReady || creation.phase == .outlining {
                        BlueprintCardsView(vm: creation)
                            .id("blueprint")
                        OutlineBatchControls(vm: creation)
                            .id("outlineControls")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(AppTheme.spacing[2])
                .animation(AppTheme.Spring.standard, value: thread.messages.count)
            }
            .zmOnChange(of: thread.messages.count) { _ in
                scrollListToBottom(proxy)
            }
            .zmOnChange(of: streamingText) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .zmOnChange(of: creation.progress.stage) { _ in
                // 流式开始/进入输出/结束都触发一次，让状态行与生成结果进入视野
                scrollListToBottom(proxy)
            }
            .zmOnChange(of: creation.phase) { _ in
                scrollListToBottom(proxy)
            }
            .zmOnChange(of: creation.isStreaming) { _ in
                scrollListToBottom(proxy)
            }
            .zmOnChange(of: creation.outlineDone) { _ in
                scrollListToBottom(proxy)
            }
            .zmOnChange(of: creation.volumeDone) { _ in
                scrollListToBottom(proxy)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }

    /// 触底滚动 helper：大卡片/气泡插入后内容布局通常滞后一帧，
    /// 先无动画定位、下一轮运行循环再动画滚动到「bottom」锚点，避免滚到内容中部产生空白区
    private func scrollListToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(AppTheme.Spring.standard) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var emptyHint: some View {
        ScrollView {
            EmptyStateView(
                title: isCreation ? "立项对话" : "写作助手",
                systemImage: isCreation ? "wand.and.stars" : "bubble.left.and.bubble.right",
                description: isCreation
                    ? "输入一句话创意，AI 会先问你几个问题理清思路，再一起定结构、出蓝图、分批生成细纲"
                    : "就这部作品向助手提问：剧情走向、人物动机、写作技法…"
            )
            .padding(.top, AppTheme.spacing[4])
        }
    }

    // MARK: - 立项阶段操作区

    private var creationActions: some View {
        VStack(spacing: AppTheme.spacing[1]) {
            // 固定区流式反馈：无论列表滚动到哪，生成中这里始终可见当前状态（streaming 外 body 为空）
            StreamingStatusView(tracker: creation.progress)
                .frame(maxWidth: .infinity)
            CreationStageIndicator(phase: creation.phase, volumePending: creation.volumePendingCount)
            if creation.blueprint != nil,
               creation.phase == .blueprintReady || creation.phase == .outlining {
                Button {
                    confirmBlueprint()
                } label: {
                    Label("创建作品", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacing[1])
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, AppTheme.spacing[3])
        .padding(.vertical, AppTheme.spacing[1])
        .background(.bar)
    }

    // MARK: - 发送

    private var lastUserMessage: ChatMessage? {
        thread.messages.last(where: { $0.role == "user" })
    }

    private func sendCurrentInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        send(text: text)
    }

    private func resendLastUserMessage() {
        guard let last = lastUserMessage else { return }
        send(text: last.content)
    }

    private func send(text: String) {
        guard activeProvider != nil else {
            if isCreation {
                creation.errorMessage = "尚未配置模型提供商，请先到设置页添加"
            } else {
                writingError = "尚未配置模型提供商，请先到设置页添加"
            }
            return
        }
        writingError = nil

        let userMessage = ChatMessage(role: "user", content: text)
        userMessage.thread = thread
        thread.messages.append(userMessage)
        store.save()

        if isCreation {
            routeCreation(text: text)
        } else {
            startWritingReply()
        }
    }

    // MARK: - 立项路由

    /// R18 书籍的规范注入（完整思路立项共用）
    private func r18Supplement(for text: String) -> String? {
        novel.r18Enabled ? PromptLibrary.shared.r18Supplement(forInput: text) : nil
    }

    /// 文风档案对齐注入（P2）：蓝图 style_guide 须与绑定档案一致
    private func alignmentSupplement() -> String? {
        novel.blueprintAlignmentSupplement(in: store.styleProfiles)
    }

    /// 完整思路立项自动启动时的补充注入：按 synopsis 语言注入 R18 规范（无标签注入）
    private func fullIdeaSupplement() -> String? {
        var parts: [String] = []
        if novel.r18Enabled {
            parts.append(PromptLibrary.shared.r18Supplement(forInput: novel.synopsis))
        }
        if let alignment = alignmentSupplement() {
            parts.append(alignment)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    private func routeCreation(text: String) {
        guard let provider = activeProvider else { return }
        // 会话恢复/切换模型后统一重注入，保证提案反馈、修订等非直传 provider 的分支可用
        creation.setProvider(provider)

        switch creation.phase {
        case .collecting:
            // 完整思路立项：collecting 阶段的消息一律直通结构规划（含重试「重新生成」）
            if thread.skipsClarification {
                creation.sendFullIdea(text: text, provider: provider, supplement: r18Supplement(for: text))
                return
            }
            // 智能注入：仅「已启用标签」且输入命中其关键词时，才附加预设内容
            var parts: [String] = []
            if let tags = PromptLibrary.shared.matchedSupplement(enabledIDs: novel.enabledTagIDs, input: text) {
                parts.append(tags)
            }
            if novel.r18Enabled {
                parts.append(PromptLibrary.shared.r18Supplement(forInput: text))
            }
            if let alignment = alignmentSupplement() {
                parts.append(alignment)
            }
            let supplement = parts.isEmpty ? nil : parts.joined(separator: "\n\n")
            creation.sendCollecting(text: text, provider: provider, supplement: supplement)
        case .proposing:
            creation.sendProposalFeedback(text)
        case .blueprintReady, .outlining, .confirmed:
            // 已有蓝图：作为修订意见（R18 书籍同样携带对应语言规范与文风对齐）
            var reviseSupplement: String? = nil
            if let alignment = alignmentSupplement() {
                reviseSupplement = alignment
            }
            if novel.r18Enabled {
                let r18 = PromptLibrary.shared.r18Supplement(forInput: text)
                reviseSupplement = reviseSupplement.map { $0 + "\n\n" + r18 } ?? r18
            }
            creation.revise(feedback: text, provider: provider, supplement: reviseSupplement)
        }
    }

    private func settleCreation(kind: CreationSessionViewModel.StreamKind,
                                message: String?,
                                raw: String,
                                parsed: Bool) {
        if let message {
            appendAssistant(message)
        } else if !parsed, !raw.isEmpty,
                  kind == .structure || kind == .foundation || kind == .revise {
            // 解析失败：展示原始输出供检查
            appendAssistant(raw)
        }
        store.save()
    }

    private func confirmBlueprint() {
        let pending = creation.outlineTotal - creation.outlineDone
        creation.confirm(into: novel, store: store)
        var text = "作品《\(novel.title)》已创建：角色、世界观与卷章结构已就位。去「章节」页签开始写作吧！"
        if pending > 0 {
            text += "（\(pending) 章细纲未生成，可稍后在「大纲」页补充）"
        }
        appendAssistant(text)
        store.save()
    }

    // MARK: - 写作助手

    private func startWritingReply() {
        guard let provider = activeProvider else { return }
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            writingError = "当前提供商缺少有效的 Base URL 或 API Key"
            return
        }

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)

        // R18 与读写协议先算好：注入文本要参与输入预算扣减（v1.7）
        let r18Text: String?
        if novel.r18Enabled {
            let sample = lastUserMessage?.content ?? thread.messages.last(where: { $0.role == "user" })?.content ?? ""
            r18Text = PromptLibrary.shared.r18Supplement(forInput: sample)
        } else {
            r18Text = nil
        }
        // 读写模式：注入补丁协议——模型只能“提议”，写入永远由用户在确认卡上显式触发
        let rwProtocol: String? = accessMode == .readWrite
            ? PromptLibrary.shared.resolvedText(for: PromptID.assistantReadWrite)
            : nil

        // 文风档案卡（.writing variant）：助手回答也贴合本书文风
        let styleCard = novel.styleProfileCard(in: store.styleProfiles, variant: .writing)

        var system = PromptTemplates.writingAssistantSystem(
            title: novel.title,
            synopsis: novel.synopsis,
            styleGuide: novel.styleGuide,
            styleCard: styleCard
        )
        // 设定上下文：让助手读懂角色状态/世界观/叙事账本/全书结构与最近实际走向（两种模式都注入）
        let budget = PromptTemplates.adjustedInputBudget(
            base: provider.contextBudgetChars,
            injections: r18Text, rwProtocol, provider.systemPromptExtra)
        let settings = ContextBuilder.buildAssistantContext(novel: novel, budgetChars: budget)
        if !settings.rendered.isEmpty {
            system += "\n\n" + settings.rendered
        }
        // R18 增强：按最近一条用户输入的语言注入对应版本规范
        if let r18 = r18Text {
            system += "\n\n" + r18
        }
        var messages: [LLMMessage] = [.init(role: .system, content: system)]
        if let rw = rwProtocol {
            messages = PromptTemplates.applying(providerExtra: rw, to: messages)
        }
        messages = PromptTemplates.applying(providerExtra: provider.systemPromptExtra, to: messages)
        // 历史单条截断（v1.7）：条数仍取最近 12 条，单条超长保留开头，防止单条巨文撑爆请求
        for message in thread.messages.suffix(12) {
            messages.append(.init(role: message.role == "user" ? .user : .assistant,
                                  content: String(message.content.prefix(PromptLimits.historyMessageCap))))
        }

        // 体量护栏：超过告警线需确认后才进入流式状态（v1.7）
        let totalChars = messages.totalContentChars
        streamTask?.cancel()
        streamTask = Task { @MainActor in
            guard await PromptGuard.authorized(totalChars: totalChars) else { return }
            isStreaming = true
            streamingText = ""
            assistantProgress.begin()
            KeepAwake.set(true)
            var raw = ""
            // 流式节流：约 100ms 刷一次 UI，避免逐字重渲染卡顿
            var lastFlush = Date.distantPast
            do {
                for try await event in client.streamChat(messages: messages, config: config) {
                    assistantProgress.handle(event)
                    if case .content(let delta) = event {
                        raw += delta
                        let now = Date()
                        if now.timeIntervalSince(lastFlush) >= 0.1 {
                            streamingText = raw
                            lastFlush = now
                        }
                    }
                }
                streamingText = raw
                if !Task.isCancelled, !raw.isEmpty {
                    if let patch = archiveWritingReply(raw) { pendingPatch = patch }
                }
            } catch is CancellationError {
                if !raw.isEmpty, let patch = archiveWritingReply(raw) { pendingPatch = patch }
            } catch {
                writingError = error.localizedDescription
            }
            assistantProgress.finish()
            isStreaming = false
            KeepAwake.set(false)
            store.save()
        }
    }

    private func stopStreaming() {
        if isCreation {
            // 由 VM 取消并经 onStreamSettled 收尾（保留已生成部分）
            creation.stop()
        } else {
            streamTask?.cancel()
        }
    }

    private func appendAssistant(_ content: String) {
        let message = ChatMessage(role: "assistant", content: content)
        message.thread = thread
        thread.messages.append(message)
    }

    /// 回复入档：读写模式剥离补丁 JSON 并挂起提案卡（空文本不产生气泡）；只读原样入档。
    /// 新提议会覆盖尚未处理的旧提议。
    @discardableResult
    private func archiveWritingReply(_ raw: String) -> AssistantPatch? {
        guard accessMode == .readWrite else {
            appendAssistant(raw)
            return nil
        }
        let (patch, cleaned) = AssistantPatch.extract(in: raw)
        if !cleaned.isEmpty { appendAssistant(cleaned) }
        return patch
    }

    private func applyPatch(_ patch: AssistantPatch) {
        ZMHaptics.success()
        let results = patch.apply(to: novel, store: store)
        pendingPatch = nil
        appliedNotice = results.isEmpty ? "补丁中没有可应用的变更。" : results.joined(separator: "\n")
    }
}

// MARK: - 立项阶段指示

private struct CreationStageIndicator: View {
    let phase: CreationSessionViewModel.Phase
    /// 未生成的卷纲数：blueprintReady 阶段以此为界显示「蓝图」或「卷纲」
    var volumePending: Int = 0

    private var stages: [(name: String, index: Int)] {
        [("思路", 0), ("结构", 1), ("蓝图", 2), ("卷纲", 3), ("细纲", 4), ("完成", 5)]
    }
    private var currentIndex: Int {
        switch phase {
        case .collecting: return 0
        case .proposing: return 1
        case .blueprintReady: return volumePending > 0 ? 3 : 2
        case .outlining: return 4
        case .confirmed: return 5
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing[1]) {
            ForEach(stages, id: \.name) { stage in
                HStack(spacing: 3) {
                    if stage.index < currentIndex {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                    }
                    Text(stage.name)
                        .font(.caption)
                }
                .foregroundStyle(stage.index <= currentIndex ? Color.accentColor : Color.secondary)
                if stage.index < stages.count - 1 {
                    Text("›")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - 结构提案卡

private struct StructureProposalCard: View {
    @ObservedObject var vm: CreationSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
            Label("结构提案（可先调整再确认）", systemImage: "square.grid.3x3")
                .font(.subheadline.weight(.semibold))

            if let concept = vm.proposal?.concept, !concept.isEmpty {
                Text(concept)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: AppTheme.spacing[1]) {
                let volumes = vm.proposal?.volumes ?? []
                let total = volumes.reduce(0) { $0 + ($1.chapter_count ?? 0) }
                ForEach(Array(volumes.enumerated()), id: \.offset) { _, volume in
                    HStack {
                        Text(volume.name ?? "未命名卷")
                            .font(.subheadline)
                        Spacer()
                        Text("\(volume.chapter_count ?? 0) 章")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("合计")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(volumes.count) 卷 · \(total) 章")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppTheme.spacing[2])
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

            Button {
                vm.confirmProposal()
            } label: {
                Label("确认结构，生成蓝图", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isStreaming)
        }
        .padding(AppTheme.spacing[2])
        .zmCard(cornerRadius: AppTheme.radiusCard)
    }
}

// MARK: - 卷纲/细纲分批控制卡

private struct OutlineBatchControls: View {
    @ObservedObject var vm: CreationSessionViewModel

    private var allDone: Bool { vm.outlineDone >= vm.outlineTotal && vm.outlineTotal > 0 }
    /// 卷纲是否全部就绪（无卷或全部已生成）
    private var volumesReady: Bool { vm.volumePendingCount == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            // 卷纲批次：未全部生成时优先展示（细纲依赖卷纲）
            if !volumesReady {
                Label("卷纲进度 \(vm.volumeDone)/\(vm.volumeTotal) 卷", systemImage: "books.vertical")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: AppTheme.spacing[2]) {
                    Picker("每轮", selection: $vm.volumesPerBatch) {
                        Text("1 卷").tag(1)
                        Text("2 卷").tag(2)
                        Text("3 卷").tag(3)
                        Text("4 卷").tag(4)
                        Text("5 卷").tag(5)
                    }
                    .pickerStyle(.segmented)
                    Toggle("自动连续", isOn: $vm.autoContinue)
                        .font(.footnote)
                }
                if vm.isStreaming {
                    Button {
                        vm.stop()
                    } label: {
                        Label("停止生成", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        vm.generateNextVolumeBatch()
                    } label: {
                        Label("生成下一批卷纲", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider().opacity(volumesReady ? 0 : 0.5)

            Label("细纲进度 \(vm.outlineDone)/\(vm.outlineTotal) 章", systemImage: "chart.bar.doc.horizontal")
                .font(.subheadline.weight(.semibold))

            if allDone {
                Label("细纲已全部生成，点下方「创建作品」落库", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if volumesReady {
                HStack(spacing: AppTheme.spacing[2]) {
                    Picker("每轮", selection: $vm.chaptersPerBatch) {
                        Text("1 章").tag(1)
                        Text("2 章").tag(2)
                        Text("3 章").tag(3)
                        Text("4 章").tag(4)
                        Text("5 章").tag(5)
                    }
                    .pickerStyle(.segmented)
                    Toggle("自动连续", isOn: $vm.autoContinue)
                        .font(.footnote)
                }
                if vm.isStreaming {
                    Button {
                        vm.stop()
                    } label: {
                        Label("停止生成", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        vm.generateNextBatch()
                    } label: {
                        Label("生成下一批细纲", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("先生成卷纲，完成后即可分批生成细纲")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacing[2])
        .zmCard(cornerRadius: AppTheme.radiusCard)
    }
}

// MARK: - 读写模式的补丁确认卡

/// 列出拟议变更，用户显式「应用」后才写入数据层；「忽略」直接丢弃。
/// 提案本身不持久化，离开页面即消失。
private struct PatchProposalCard: View {
    let summary: String?
    let lines: [String]
    let onApply: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            Label("助手提议修改设定", systemImage: "wand.and.stars")
                .font(.subheadline.bold())
            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text("• \(line)")
                    .font(.caption)
            }
            HStack(spacing: AppTheme.spacing[2]) {
                Button(action: onApply) {
                    Label("应用", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive, action: onIgnore) {
                    Text("忽略")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .zmCard(cornerRadius: AppTheme.radiusCard)
    }
}
#endif

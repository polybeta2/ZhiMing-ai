import SwiftUI

/// 通用聊天页（立项与写作助手共用）
/// 能力：消息持久化到 ChatThread、流式气泡、停止、重发最后一条、会话内切换模型
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
    @State private var lastCreationWasRevise = false
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
            if isCreation, creation.phase == .revising, creation.blueprint != nil {
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
                ChatInputBar(
                    text: $input,
                    isStreaming: isStreaming,
                    placeholder: isCreation ? "输入创意或修改意见…" : "向写作助手提问…",
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
                    .disabled(isStreaming || lastUserMessage == nil)

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
            if isCreation, thread.messages.isEmpty, input.isEmpty, !novel.synopsis.isEmpty {
                input = novel.synopsis
            }
        }
        .onDisappear { streamTask?.cancel() }
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
                    if thread.messages.isEmpty && !isStreaming {
                        emptyHint
                    }
                    ForEach(thread.messages) { message in
                        MessageBubbleView(role: message.role, text: message.content)
                            .id(message.id)
                    }
                    if isStreaming {
                        MessageBubbleView(role: "assistant", text: streamingText, isStreaming: true)
                            .id("streaming")
                    }
                    if isCreation, creation.blueprint != nil, creation.phase == .revising {
                        BlueprintCardsView(vm: creation)
                            .id("blueprint")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(AppTheme.spacing[2])
                .animation(AppTheme.Spring.standard, value: thread.messages.count)
            }
            .zmOnChange(of: thread.messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .zmOnChange(of: streamingText) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .zmOnChange(of: creation.phase) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }

    private var emptyHint: some View {
        ScrollView {
            EmptyStateView(
                title: isCreation ? "立项对话" : "写作助手",
                systemImage: isCreation ? "wand.and.stars" : "bubble.left.and.bubble.right",
                description: isCreation
                    ? "输入一句话创意，AI 生成可编辑的作品蓝图"
                    : "就这部作品向助手提问：剧情走向、人物动机、写作技法…"
            )
            .padding(.top, AppTheme.spacing[4])
        }
    }

    private var creationActions: some View {
        HStack {
            Button {
                confirmBlueprint()
            } label: {
                Label("创建作品", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing[1])
            }
            .buttonStyle(.borderedProminent)
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

    private func routeCreation(text: String) {
        guard let provider = activeProvider else { return }

        if creation.phase == .revising {
            // 已有蓝图：作为修订意见（R18 书籍同样携带对应语言规范）
            lastCreationWasRevise = true
            beginCreationStream()
            var reviseSupplement: String?
            if novel.r18Enabled {
                reviseSupplement = PromptLibrary.shared.r18Supplement(forInput: text)
            }
            creation.revise(feedback: text, provider: provider, supplement: reviseSupplement)
        } else {
            // 无蓝图：作为创意生成蓝图（「重新生成」回退到最初创意）
            let brief = (text.contains("重新生成") && !novel.synopsis.isEmpty) ? novel.synopsis : text
            // 智能注入：仅「已启用标签」且输入命中其关键词时，才附加预设内容
            var parts: [String] = []
            if let tags = PromptLibrary.shared.matchedSupplement(enabledIDs: novel.enabledTagIDs, input: brief) {
                parts.append(tags)
            }
            if novel.r18Enabled {
                parts.append(PromptLibrary.shared.r18Supplement(forInput: brief))
            }
            let supplement = parts.isEmpty ? nil : parts.joined(separator: "\n\n")
            lastCreationWasRevise = false
            beginCreationStream()
            creation.generateBlueprint(brief: brief, provider: provider, supplement: supplement)
        }
    }

    private func beginCreationStream() {
        isStreaming = true
        streamingText = ""
        creation.onStreamSettled = { raw, parsed in
            settleCreation(raw: raw, parsed: parsed)
        }
        observeCreationStream()
    }

    /// 把 VM 的 draft 镜像到气泡
    private func observeCreationStream() {
        streamTask?.cancel()
        streamTask = Task { @MainActor in
            while isStreaming {
                streamingText = creation.draft
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func settleCreation(raw: String, parsed: Bool) {
        isStreaming = false
        streamTask?.cancel()
        streamingText = ""

        if parsed {
            let title = creation.blueprint?.title_suggestion ?? novel.title
            let content = lastCreationWasRevise
                ? "已按你的意见修订蓝图，继续查看卡片或提出更多意见。"
                : "已生成《\(title)》的蓝图，请在卡片中审阅与编辑；也可以直接告诉我修改意见。"
            appendAssistant(content)
        } else if !raw.isEmpty {
            appendAssistant(raw)
        }
        store.save()
    }

    private func confirmBlueprint() {
        creation.confirm(into: novel, store: store)
        appendAssistant("作品《\(novel.title)》已创建：角色、世界观与卷章结构已就位。去「章节」页签开始写作吧！")
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

        var system = PromptTemplates.writingAssistantSystem(
            title: novel.title,
            synopsis: novel.synopsis,
            styleGuide: novel.styleGuide
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
            KeepAwake.set(true)
            var raw = ""
            // 流式节流：约 100ms 刷一次 UI，避免逐字重渲染卡顿
            var lastFlush = Date.distantPast
            do {
                for try await delta in client.streamChat(messages: messages, config: config) {
                    raw += delta
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.1 {
                        streamingText = raw
                        lastFlush = now
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

/// 读写模式的补丁确认卡：列出拟议变更，用户显式「应用」后才写入数据层；
/// 「忽略」直接丢弃。提案本身不持久化，离开页面即消失。
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

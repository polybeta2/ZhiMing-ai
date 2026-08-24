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

    private var isCreation: Bool { thread.purpose == "creation" }
    private var activeProvider: ProviderConfig? { sessionProvider ?? store.defaultProvider }
    private var currentModelName: String {
        activeProvider?.modelName ?? "未配置"
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
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
                                .frame(width: 90)
                        }
                        .font(.caption)
                    }
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
            // 已有蓝图：作为修订意见
            lastCreationWasRevise = true
            beginCreationStream()
            creation.revise(feedback: text, provider: provider)
        } else {
            // 无蓝图：作为创意生成蓝图（「重新生成」回退到最初创意）
            let brief = (text.contains("重新生成") && !novel.synopsis.isEmpty) ? novel.synopsis : text
            lastCreationWasRevise = false
            beginCreationStream()
            creation.generateBlueprint(brief: brief, provider: provider)
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

        var messages: [LLMMessage] = []
        var system = "你是小说《\(novel.title)》的写作助手，帮助作者头脑风暴、解答剧情与技法问题，回答简洁具体。"
        if !novel.synopsis.isEmpty { system += "\n作品梗概：\(novel.synopsis)" }
        if let style = novel.styleGuide, !style.isEmpty { system += "\n风格约束：\(style)" }
        messages.append(.init(role: .system, content: system))
        messages = PromptTemplates.applying(providerExtra: provider.systemPromptExtra, to: messages)
        for message in thread.messages.suffix(12) {
            messages.append(.init(role: message.role == "user" ? .user : .assistant, content: message.content))
        }

        isStreaming = true
        streamingText = ""
        KeepAwake.set(true)
        streamTask?.cancel()
        streamTask = Task { @MainActor in
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
                    appendAssistant(raw)
                }
            } catch is CancellationError {
                if !raw.isEmpty { appendAssistant(raw) }
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
}

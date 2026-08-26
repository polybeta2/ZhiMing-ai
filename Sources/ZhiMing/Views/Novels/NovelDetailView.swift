import SwiftUI

/// 作品工作台：章节 / 设定 / 统计 / 助手 四页签 + 工具栏导出入口
struct NovelDetailView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var novel: Novel

    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "章节"
        case settings = "设定"
        case assistant = "助手"
        case stats = "统计"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .chapters
    @State private var showExport = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("页签", selection: $tab) {
                ForEach(Tab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.spacing[3])
            .padding(.vertical, AppTheme.spacing[1])

            switch tab {
            case .chapters:
                ChapterListView(novel: novel)
            case .settings:
                NovelSettingsTab(novel: novel)
            case .assistant:
                AssistantPane(novel: novel)
            case .stats:
                StatisticsView(novel: novel)
            }
        }
        .navigationTitle(novel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExport) { ExportSheet(novel: novel) }
        // 一句话立项未完成时直接落到助手页签（立项对话）
        .onAppear {
            if novel.hasPendingCreationThread { tab = .assistant }
        }
    }
}

extension Novel {
    /// 存在立项会话且蓝图尚未确认（卷与角色仍为空）→ 视为立项进行中
    var hasPendingCreationThread: Bool {
        chatThreads.contains { $0.purpose == "creation" }
            && volumes.isEmpty
            && characters.isEmpty
    }
}

/// 设定页签：角色卡 / 世界观 / 大纲 入口
private struct NovelSettingsTab: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var novel: Novel

    // R18 开关（与建书表单共用确认状态）
    @AppStorage("r18.notice.confirmed.v1") private var r18NoticeConfirmed = false
    @State private var showR18Notice = false

    private var r18Binding: Binding<Bool> {
        Binding(
            get: { novel.r18Enabled },
            set: { newValue in
                if newValue && !r18NoticeConfirmed {
                    showR18Notice = true
                } else {
                    applyR18(newValue)
                }
            }
        )
    }

    private func applyR18(_ enabled: Bool) {
        novel.r18Enabled = enabled
        if enabled {
            novel.accentColorHex = Novel.r18AccentHex
        } else if novel.accentColorHex == Novel.r18AccentHex {
            novel.accentColorHex = AppTheme.accentPresets[0].hexString
        }
        store.save()
    }

    var body: some View {
        List {
            Section("作品设定") {
                NavigationLink(destination: CharacterListView(novel: novel)) {
                    Label {
                        HStack {
                            Text("角色卡")
                            Spacer()
                            Text("\(novel.characters.count)")
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        ZMSettingsIcon(systemName: "person.2.fill", tint: .blue)
                    }
                }
                NavigationLink(destination: WorldListView(novel: novel)) {
                    Label {
                        HStack {
                            Text("世界观")
                            Spacer()
                            Text("\(novel.worldEntries.count)")
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        ZMSettingsIcon(systemName: "globe.asia.australia.fill", tint: .green)
                    }
                }
                NavigationLink(destination: OutlineView(novel: novel)) {
                    Label {
                        HStack {
                            Text("大纲")
                            Spacer()
                            Text("\(novel.volumes.count) 卷")
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        ZMSettingsIcon(systemName: "list.number", tint: .indigo)
                    }
                }
            }
            Section("简介") {
                VStack(alignment: .leading, spacing: 6) {
                    if !novel.synopsis.isEmpty {
                        Text(novel.synopsis)
                            .font(.subheadline)
                    }
                    if let perspective = novel.perspective {
                        Text("视角：\(perspective)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let style = novel.styleGuide {
                        Text("风格：\(style)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, AppTheme.spacing[0])
            }
            Section("成人内容") {
                Toggle(isOn: r18Binding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("R18 增强（虚构情色写作辅助）")
                        Text(novel.r18Enabled
                             ? "已开启：写作请求自动注入对应语言的本地 R18 规范；强调色锁定血红"
                             : "关闭中；开启后强调色强制血红色并标注 R18 Enabled")
                            .font(.caption)
                            .foregroundStyle(novel.r18Enabled ? Color.red : .secondary)
                    }
                }
                if showR18Notice {
                    InlineConfirmCard(
                        title: "启用 R18 增强？",
                        message: Novel.r18NoticeText,
                        confirmLabel: "同意并开启",
                        onConfirm: {
                            r18NoticeConfirmed = true
                            withAnimation {
                                applyR18(true)
                                showR18Notice = false
                            }
                        },
                        onCancel: { withAnimation { showR18Notice = false } }
                    )
                }
            }
        }
    }
}

/// 助手页签：立项对话优先（未完成时），否则写作助手会话
private struct AssistantPane: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel
    @State private var thread: ChatThread?

    var body: some View {
        Group {
            if let thread {
                ChatView(novel: novel, thread: thread)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard thread == nil else { return }
            // 立项进行中 → 打开立项会话（创意输入已预填 novel.synopsis）
            if novel.hasPendingCreationThread,
               let creation = novel.chatThreads.first(where: { $0.purpose == "creation" }) {
                thread = creation
                return
            }
            if let existing = novel.chatThreads.first(where: { $0.purpose == "writing" }) {
                thread = existing
            } else {
                let created = ChatThread(purpose: "writing")
                created.novel = novel
                novel.chatThreads.append(created)
                store.save()
                thread = created
            }
        }
    }
}

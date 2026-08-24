import SwiftUI

/// 作品工作台：章节 / 设定 / 助手 三页签
struct NovelDetailView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var novel: Novel

    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "章节"
        case settings = "设定"
        case assistant = "助手"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .chapters

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
            }
        }
        .navigationTitle(novel.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 设定页签：角色卡 / 世界观 / 大纲 入口
private struct NovelSettingsTab: View {
    @ObservedObject var novel: Novel

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
                        Image(systemName: "person.2")
                            .foregroundStyle(Color.accentColor)
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
                        Image(systemName: "globe.asia.australia")
                            .foregroundStyle(Color.accentColor)
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
                        Image(systemName: "list.number")
                            .foregroundStyle(Color.accentColor)
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
        }
    }
}

/// 助手页签：写作助手会话
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

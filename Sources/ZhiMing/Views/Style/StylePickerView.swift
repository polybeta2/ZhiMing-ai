#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 为本书选择启用的文风档案（nil = 不启用）
struct StylePickerView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var novel: Novel

    private var boundName: String? {
        novel.activeStyleProfile(in: store.styleProfiles)?.name
    }

    var body: some View {
        List {
            Section("本书启用") {
                Button {
                    novel.activeStyleProfileID = nil
                    store.save()
                } label: {
                    HStack {
                        Text("不启用")
                        Spacer()
                        if novel.activeStyleProfileID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                ForEach(store.styleProfiles) { profile in
                    Button {
                        novel.activeStyleProfileID = profile.id
                        store.save()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                if !profile.tags.isEmpty {
                                    Text(profile.tags.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if novel.activeStyleProfileID == profile.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section(footer: Text("启用后：续写/撰写/改写请求自动注入该档案的语言机制约束；手填的【风格约束】优先级更高。")) {
                NavigationLink(destination: StyleLibraryView()) {
                    Text("管理风格库（编辑 / 蒸馏新档案）")
                }
            }
        }
        .navigationTitle(boundName.map { "文风：\($0)" } ?? "文风档案")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 编辑器会话内文风三态选择（不落库，仅当前编辑页生效）
struct SessionStylePickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: ChapterEditorView.SessionStyle
    let novel: Novel?

    var body: some View {
        CompatNavigationView {
            List {
                Section(footer: Text("仅对当前编辑页生效，不写入书籍设置；长期启用请到「设定 → 文风档案」绑定。")) {
                    row(.followBook,
                        title: "跟随书籍绑定",
                        subtitle: novel.flatMap { $0.activeStyleProfile(in: store.styleProfiles) }?.name ?? "（书未绑定档案）")
                    row(.off, title: "不启用", subtitle: nil)
                    ForEach(store.styleProfiles) { profile in
                        row(.custom(profile.id), title: profile.name,
                            subtitle: profile.tags.isEmpty ? nil : profile.tags.joined(separator: " · "))
                    }
                }
            }
            .navigationTitle("会话文风")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ value: ChapterEditorView.SessionStyle, title: String, subtitle: String?) -> some View {
        Button {
            selection = value
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == value {
                    Image(systemName: "checkmark")
                }
            }
        }
        .buttonStyle(.plain)
    }
}
#endif

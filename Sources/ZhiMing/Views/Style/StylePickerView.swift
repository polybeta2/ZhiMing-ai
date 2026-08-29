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
#endif

#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 通用删除确认卡（v1.5.2 教训：删除确认走 sheet 内嵌确认卡，不用系统弹窗）
struct DeleteConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary)
            InlineConfirmCard(
                title: title,
                message: message,
                confirmLabel: "删除",
                onConfirm: {
                    onConfirm()
                    dismiss()
                },
                onCancel: { dismiss() }
            )
            Spacer()
        }
        .padding()
    }
}

/// 全局风格库：列表 + 新建蒸馏 + 删除（被绑定时二次确认）
struct StyleLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDistill = false
    @State private var showFusion = false
    @State private var deletingProfile: StyleProfile?

    var body: some View {
        Group {
            if store.styleProfiles.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateView(title: "还没有文风档案", systemImage: "textformat",
                                   description: "从样章蒸馏一份专属文风，写作时一键启用")
                    Button {
                        showDistill = true
                    } label: {
                        Label("开始蒸馏", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.styleProfiles) { profile in
                        NavigationLink(destination: StyleProfileDetailView(profile: profile)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).font(.headline)
                                if !profile.tags.isEmpty {
                                    Text(profile.tags.joined(separator: " · "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Text("样本 \(profile.sampleCharCount) 字 · 置信度\(profile.confidence) · 绑定 \(store.bindingCount(of: profile)) 本书")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let first = indexSet.first {
                            deletingProfile = store.styleProfiles[first]
                        }
                    }
                }
            }
        }
        .navigationTitle("文风档案库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppTheme.spacing[2]) {
                    if store.styleProfiles.count >= 2 {
                        Button {
                            showFusion = true
                        } label: {
                            Image(systemName: "arrow.triangle.merge")
                        }
                    }
                    Button {
                        showDistill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showDistill) { StyleDistillSheet() }
        .sheet(isPresented: $showFusion) { StyleFusionSheet() }
        .sheet(item: $deletingProfile) { profile in
            DeleteConfirmSheet(
                title: "删除「\(profile.name)」？",
                message: store.bindingCount(of: profile) > 0
                    ? "该档案已被 \(store.bindingCount(of: profile)) 本书绑定，删除后这些书将自动解绑。"
                    : "删除后不可恢复。"
            ) {
                store.deleteStyleProfile(profile)
            }
        }
    }
}
#endif

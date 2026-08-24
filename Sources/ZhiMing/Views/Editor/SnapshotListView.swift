import SwiftUI

/// 版本历史与回退（对标司命版本历史）
/// 行：版本号 + 触发类型徽标（手动/AI/回退）+ 时间 + 字数；点击预览，确认后回退
struct SnapshotListView: View {
    @Environment(AppStore.self) private var store
    let chapter: Chapter

    @State private var previewing: ChapterSnapshot?
    @State private var restoring: ChapterSnapshot?

    private var sortedSnapshots: [ChapterSnapshot] {
        chapter.snapshots.sorted { $0.versionNumber > $1.versionNumber }
    }

    var body: some View {
        List {
            if chapter.snapshots.isEmpty {
                Section {
                    Text("AI 采纳与手动保存会自动创建版本。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(sortedSnapshots) { snapshot in
                Button {
                    previewing = snapshot
                } label: {
                    SnapshotRow(snapshot: snapshot)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("版本历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    SnapshotService.snapshot(chapter, trigger: "manual_save")
                    store.save()
                } label: {
                    Label("保存当前版本", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(item: $previewing) { snapshot in
            SnapshotPreviewSheet(snapshot: snapshot) {
                restoring = snapshot
            }
        }
        .confirmationDialog(
            "回退到版本 \(restoring?.versionNumber ?? 0)？",
            isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
            titleVisibility: .visible
        ) {
            Button("回退到此版本", role: .destructive) {
                if let snapshot = restoring {
                    SnapshotService.restore(chapter, to: snapshot)
                    store.save()
                }
                restoring = nil
                previewing = nil
            }
            Button("取消", role: .cancel) { restoring = nil }
        } message: {
            Text("回退前会先把当前内容存为新的 restore 版本，历史不会丢失。")
        }
    }
}

private struct SnapshotRow: View {
    let snapshot: ChapterSnapshot

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            Text("v\(snapshot.versionNumber)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .frame(width: 44, alignment: .leading)

            triggerBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(snapshot.content.count) 字")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppTheme.spacing[0])
        .contentShape(Rectangle())
    }

    private var triggerBadge: some View {
        let (text, color): (String, Color)
        switch snapshot.triggerType {
        case "manual_save": (text, color) = ("手动", .blue)
        case "ai_insert": (text, color) = ("AI", .purple)
        case "restore": (text, color) = ("回退", .orange)
        default: (text, color) = (snapshot.triggerType, .gray)
        }
        return Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct SnapshotPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: ChapterSnapshot
    var onRestore: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(snapshot.content.isEmpty ? "（该版本无正文）" : snapshot.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacing[3])
            }
            .navigationTitle("版本 \(snapshot.versionNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("回退到此版本", role: .destructive) {
                        dismiss()
                        onRestore()
                    }
                }
            }
        }
    }
}

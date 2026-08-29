#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

extension ForeshadowStatus {
    /// 状态显示名
    var displayName: String {
        switch self {
        case .open: return "未回收"
        case .resolved: return "已回收"
        case .dropped: return "废弃"
        }
    }

    /// 状态徽标色
    var tintColor: Color {
        switch self {
        case .open: return .orange
        case .resolved: return .green
        case .dropped: return .gray
        }
    }
}

extension Foreshadowing {
    /// 排序权重：open < resolved < dropped
    var statusSortRank: Int {
        switch status {
        case .open: return 0
        case .resolved: return 1
        case .dropped: return 2
        }
    }
}

/// 伏笔新增 / 编辑 sheet
struct ForeshadowEditSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let novel: Novel
    var existing: Foreshadowing?

    @State private var title = ""
    @State private var detail = ""
    @State private var volumeIndex = 0        // 0 = 未知
    @State private var chapterOrder = 0       // 0 = 未知
    @State private var plannedResolve = ""
    @State private var note = ""
    @State private var status: ForeshadowStatus = .open

    /// 当前选中的卷（0 = 未知时为空）
    private var selectedVolume: Volume? {
        volumeIndex > 0 ? novel.sortedVolumes[safe: volumeIndex - 1] : nil
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("伏笔内容") {
                    TextField("标题（必填）", text: $title)
                    MultilineField(text: $detail, placeholder: "具体内容 / 原文引用（可选）", minHeight: 70)
                    MultilineField(text: $note, placeholder: "作者备注（可选）", minHeight: 50)
                }
                Section("埋设位置") {
                    Picker("卷", selection: $volumeIndex) {
                        Text("未知").tag(0)
                        ForEach(novel.sortedVolumes.indices, id: \.self) { i in
                            Text(novel.sortedVolumes[i].name).tag(i + 1)
                        }
                    }
                    if let volume = selectedVolume {
                        Picker("章", selection: $chapterOrder) {
                            Text("未知").tag(0)
                            ForEach(volume.sortedChapters, id: \.id) { chapter in
                                Text(chapter.title).tag(chapter.sortOrder)
                            }
                        }
                    }
                }
                Section("回收") {
                    TextField("计划回收位置（如：第三卷末）", text: $plannedResolve)
                    Picker("状态", selection: $status) {
                        ForEach([ForeshadowStatus.open, .resolved, .dropped], id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(existing == nil ? "新增伏笔" : "编辑伏笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// 编辑态回填
    private func load() {
        guard let existing else { return }
        title = existing.title
        detail = existing.detail ?? ""
        volumeIndex = existing.plantedVolumeIndex ?? 0
        chapterOrder = existing.plantedChapterOrder ?? 0
        plannedResolve = existing.plannedResolve ?? ""
        note = existing.note ?? ""
        status = existing.status
    }

    /// 保存（替换或新增）
    private func save() {
        let cap = PromptLimits.foreshadowTextFieldCap
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let entry = Foreshadowing(
            id: existing?.id ?? UUID(),
            title: String(trimmedTitle.prefix(cap)),
            detail: detail.isEmpty ? nil : String(detail.prefix(cap)),
            plantedVolumeIndex: volumeIndex > 0 ? volumeIndex : nil,
            plantedChapterOrder: chapterOrder > 0 ? chapterOrder : nil,
            plannedResolve: plannedResolve.isEmpty ? nil : String(plannedResolve.prefix(cap)),
            status: status,
            note: note.isEmpty ? nil : String(note.prefix(cap)),
            suggestedResolved: existing?.suggestedResolved ?? false
        )

        if let index = novel.foreshadowings.firstIndex(where: { $0.id == entry.id }) {
            novel.foreshadowings[index] = entry
        } else {
            novel.foreshadowings.append(entry)
        }
        store.save()
        dismiss()
    }
}
#endif

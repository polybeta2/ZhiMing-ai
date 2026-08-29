import SwiftUI

/// 卷纲与章细纲编辑：卷列表（增删改卷名+卷纲），每卷下章节的细纲快捷编辑入口。
/// AI 辅助：卷纲/细纲均可流式生成草稿；「采纳」只把草稿填入编辑框，
/// 再由既有的防抖保存 / 「保存」按钮落盘，不直接覆盖数据。
struct OutlineView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel

    var body: some View {
        List {
            ForeshadowDashboardSection(store: store, novel: novel)
            if novel.volumes.isEmpty {
                Section {
                    Text("还没有卷。点击右上角 + 新建卷，再在卷下管理章节。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(novel.sortedVolumes) { volume in
                VolumeOutlineSection(store: store, volume: volume)
            }
        }
        .navigationTitle("大纲")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addVolume()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addVolume() {
        let volume = Volume(name: "第\(novel.volumes.count + 1)卷", sortOrder: novel.volumes.count + 1)
        volume.novel = novel
        novel.volumes.append(volume)
        store.save()
    }
}

/// 单卷区块：卷名/卷纲编辑（防抖保存）+ AI 卷纲生成 + 章细纲快捷编辑
private struct VolumeOutlineSection: View {
    @ObservedObject var store: AppStore
    @ObservedObject var volume: Volume

    @StateObject private var vm = OutlineAssistViewModel()
    @State private var outlineDraft = ""
    @State private var syncDraft = false
    @State private var saveTask: Task<Void, Never>?
    @State private var editingChapter: Chapter?
    @State private var renamingVolume = false
    @State private var renameText = ""
    @State private var deletingVolume = false
    @State private var renamingChapter: Chapter?
    @State private var chapterRenameText = ""
    @State private var deletingChapter: Chapter?
    @State private var showNoProviderAlert = false
    /// 草稿含 zm-dims 时是否随采纳一并写入四维
    @State private var applyDims = true
    @State private var dimsNotice: String?

    var body: some View {
        Section {
            if deletingVolume {
                // 破坏性确认用内联卡（v1.5.2 教训：系统弹窗按钮动作不可靠）
                InlineConfirmCard(
                    title: "删除「\(volume.name)」？",
                    message: "卷下的章节、正文与版本快照将一并删除，无法恢复。",
                    confirmLabel: "确认删除卷",
                    onConfirm: {
                        deletingVolume = false
                        guard let novel = volume.novel else { return }
                        novel.volumes.removeAll { $0.id == volume.id }
                        for (index, v) in novel.sortedVolumes.enumerated() { v.sortOrder = index + 1 }
                        store.save()
                    },
                    onCancel: { deletingVolume = false }
                )
            }
            MultilineField(text: $outlineDraft, placeholder: "卷纲（本卷走向概述）…", minHeight: 56)
                .zmOnChange(of: outlineDraft) { newValue in
                    guard !syncDraft else { return }
                    volume.outline = newValue.isEmpty ? nil : newValue
                    scheduleSave()
                }

            aiControls

            FourDimsEditor(store: store, volume: volume)

            if volume.chapters.isEmpty {
                Text("本卷暂无章节，可在「章节」页签添加。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            ForEach(volume.sortedChapters) { chapter in
                // 不用 Button+contextMenu 组合：iOS 15 的 List 中该组合的行级菜单会被
                // 区块级菜单吞掉（表现为长按章节弹出卷菜单）。改为普通视图：
                // 轻点进入细纲编辑，长按弹出章节菜单。
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter.title)
                        .font(.subheadline.weight(.medium))
                    Text(chapter.detailedOutline ?? "未填写细纲")
                        .font(.footnote)
                        .foregroundColor(chapter.detailedOutline == nil ? Color(uiColor: .tertiaryLabel) : .secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        chapterRenameText = chapter.title
                        renamingChapter = chapter
                    } label: {
                        Label("重命名章节", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingChapter = chapter
                    } label: {
                        Label("删除章节", systemImage: "trash")
                    }
                }
                .onTapGesture { editingChapter = chapter }

                // 确认卡紧贴被操作的行，长列表中也一眼可见
                if deletingChapter?.id == chapter.id {
                    InlineConfirmCard(
                        title: "删除「\(chapter.title)」？",
                        message: "该章的正文、版本快照与摘要将一并删除，无法恢复。",
                        confirmLabel: "确认删除章节",
                        onConfirm: {
                            deletingChapter = nil
                            volume.chapters.removeAll { $0.id == chapter.id }
                            volume.normalizeChapterOrder()
                            store.save()
                        },
                        onCancel: { deletingChapter = nil }
                    )
                }
            }

            // 批量细纲：一键生成本卷尚未写细纲的章节（每次最多 5 章，直接写回）
            let batchPending = volume.chapters.filter {
                ($0.detailedOutline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !batchPending.isEmpty {
                batchControls(pending: Array(batchPending.prefix(5)), left: batchPending.count)
            }
        } header: {
            // 卷菜单只挂在标题上：行级与区块级菜单共存时 iOS 15 会错配（长按章节弹卷菜单）
            Text(volume.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        renameText = volume.name
                        renamingVolume = true
                    } label: {
                        Label("重命名卷", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingVolume = true
                    } label: {
                        Label("删除卷", systemImage: "trash")
                    }
                }
        }
        .onAppear {
            syncDraft = true
            outlineDraft = volume.outline ?? ""
            DispatchQueue.main.async { syncDraft = false }
        }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $renamingVolume) {
            RenameSheet(title: "重命名卷", placeholder: "卷名", initialText: renameText) { newValue in
                volume.name = newValue
                store.save()
            }
        }
        .alert("尚未配置模型提供商", isPresented: $showNoProviderAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请先在「设置 → 模型提供商」中添加并测试一个 OpenAI 兼容接口。")
        }
        .alert("四维规划已更新", isPresented: Binding(
            get: { dimsNotice != nil },
            set: { if !$0 { dimsNotice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(dimsNotice ?? "")
        }
        .sheet(item: $editingChapter) { chapter in
            ChapterOutlineEditSheet(chapter: chapter)
        }
        .sheet(item: $renamingChapter) { chapter in
            RenameSheet(
                title: "重命名章节",
                placeholder: "章节名",
                initialText: chapterRenameText
            ) { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { chapter.title = trimmed }
                store.save()
            }
        }
    }

    // MARK: - 批量细纲（本卷）

    @ViewBuilder private func batchControls(pending: [Chapter], left: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            if vm.batchPhase == .streaming {
                HStack(spacing: AppTheme.spacing[1]) {
                    Button("停止", role: .destructive) { vm.stopBatch() }
                        .font(.footnote)
                    StreamingStatusView(tracker: vm.progress)
                }
            } else {
                HStack(spacing: AppTheme.spacing[1]) {
                    Button {
                        startBatch(pending)
                    } label: {
                        Label("批量生成细纲（剩余 \(left) 章，每次最多 5 章）",
                              systemImage: "text.badge.plus")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.batchPhase == .streaming)
                    if vm.batchSummary != nil {
                        Button("重新生成") { startBatch(pending) }
                            .font(.footnote)
                    }
                }
            }
            if let summary = vm.batchSummary {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(summary).font(.caption).foregroundColor(.secondary)
                }
            }
            if let error = vm.errorMessage {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, AppTheme.spacing[1])
    }

    private func startBatch(_ chapters: [Chapter]) {
        guard let provider = activeProvider else {
            showNoProviderAlert = true
            return
        }
        guard let novel = volume.novel else { return }
        vm.startBatchChapters(chapters: chapters.prefix(5).map { $0 }, volume: volume,
                              novel: novel, provider: provider, instruction: nil, store: store)
    }

    // MARK: - AI 卷纲生成

    private var activeProvider: ProviderConfig? { store.defaultProvider }

    @ViewBuilder private var aiControls: some View {
        HStack(spacing: AppTheme.spacing[1]) {
            Button {
                generate()
            } label: {
                Label(vm.phase == .streaming ? "生成中…" : "AI 生成卷纲", systemImage: "wand.and.stars")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .disabled(vm.phase == .streaming)

            if vm.phase == .streaming {
                Button("停止", role: .destructive) { vm.stop() }
                    .font(.footnote)
                ProgressView().controlSize(.small)
            }
            Spacer()
        }

        if let error = vm.errorMessage {
            Label(error, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundColor(.red)
        }

        switch vm.phase {
        case .streaming:
            VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                StreamingStatusView(tracker: vm.progress, showsOutputting: false)
                Text(vm.draft.isEmpty ? "正在生成本卷卷纲…" : vm.draft)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(10)
            }
        case .done where !vm.draft.isEmpty:
            VStack(spacing: AppTheme.spacing[1]) {
                draftCard
                if vm.extractedDims != nil {
                    Toggle("同时更新四维（情绪走向 / 冲突阶梯 / 信息差）", isOn: $applyDims)
                        .font(.caption)
                }
            }
        default:
            EmptyView()
        }
    }

    private var draftCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            Text(vm.draft)
                .font(.callout)
            if !vm.truncatedSections.isEmpty {
                Text("超预算裁剪：\(vm.truncatedSections.joined(separator: "、"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: AppTheme.spacing[1]) {
                Button {
                    acceptDraft()
                } label: {
                    Label("采纳", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    regenerate()
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    vm.reset()
                } label: {
                    Text("放弃")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func generate() {
        guard let novel = volume.novel else { return }
        guard let provider = activeProvider else {
            showNoProviderAlert = true
            return
        }
        vm.start(kind: .volume(volume), novel: novel, provider: provider, instruction: nil)
    }

    private func regenerate() {
        guard let novel = volume.novel else { return }
        guard let provider = activeProvider else {
            showNoProviderAlert = true
            return
        }
        vm.regenerate(novel: novel, provider: provider)
    }

    /// 采纳 = 填入卷纲编辑框（syncDraft 防止 onChange 回环），由防抖保存落盘；
    /// 若草稿附 zm-dims 且开关开启，四维同步写入
    private func acceptDraft() {
        let trimmed = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        syncDraft = true
        outlineDraft = trimmed
        volume.outline = trimmed.isEmpty ? nil : trimmed
        DispatchQueue.main.async { syncDraft = false }
        if applyDims, let dims = vm.extractedDims {
            let applied = dims.apply(to: volume)
            if !applied.isEmpty { dimsNotice = applied.joined(separator: "\n") }
        }
        scheduleSave()
        vm.reset()
    }

    /// 卷纲编辑防抖保存
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            store.save()
        }
    }
}

/// 章细纲编辑 sheet：手动编辑 + AI 辅助生成（增强①：附加要求输入）。
/// 采纳把草稿填入上方细纲编辑区，仍由「保存」按钮统一落库。
private struct ChapterOutlineEditSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter

    @StateObject private var vm = OutlineAssistViewModel()
    @State private var outlineDraft = ""
    @State private var aiInstruction = ""
    @State private var loaded = false
    @State private var cards: [SceneCard] = []

    var body: some View {
        CompatNavigationView {
            Form {
                Section("本章细纲") {
                    MultilineField(text: $outlineDraft, placeholder: "这一章的场景、冲突与推进…", minHeight: 140)
                }
                sceneCardsSection
                Section("AI 辅助") {
                    MultilineField(text: $aiInstruction,
                                   placeholder: "附加要求（可选）：如「本章以反派视角展开」",
                                   minHeight: 48)
                    aiControls
                }
            }
            .navigationTitle(chapter.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        vm.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = outlineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        chapter.detailedOutline = trimmed.isEmpty ? nil : trimmed
                        let cleaned = cards.filter { !$0.isEmpty }
                        chapter.sceneCards = cleaned.isEmpty ? nil : cleaned
                        store.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                outlineDraft = chapter.detailedOutline ?? ""
                cards = chapter.sceneCards ?? []
            }
            .onDisappear { vm.stop() }
        }
    }

    // MARK: - 场景卡编辑（目标 / 阻力 / 钩子）

    private var sceneCardsSection: some View {
        Section(footer: Text("每张卡描述一个场景：主角想达成什么、什么拦着、章末用什么悬念勾读者。续写时随细纲一并注入。")) {
            ForEach(cards.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("卡 \(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            cards.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("主角这场想达成什么", text: cardBinding(index, \.goal))
                        .font(.subheadline)
                    TextField("什么拦着（阻力/对手）", text: cardBinding(index, \.obstacle))
                        .font(.subheadline)
                    TextField("章末悬念钩子", text: cardBinding(index, \.hook))
                        .font(.subheadline)
                }
                .padding(.vertical, 2)
            }
            Button {
                cards.append(SceneCard())
            } label: {
                Label("添加场景卡", systemImage: "plus.circle")
            }
        }
    }

    private func cardBinding(_ index: Int, _ keyPath: WritableKeyPath<SceneCard, String>) -> Binding<String> {
        Binding(
            get: { cards[index][keyPath: keyPath] },
            set: { cards[index][keyPath: keyPath] = $0 }
        )
    }

    // MARK: - AI 细纲生成

    @ViewBuilder private var aiControls: some View {
        HStack(spacing: AppTheme.spacing[1]) {
            Button {
                generate()
            } label: {
                Label(vm.phase == .streaming ? "生成中…" : "AI 生成细纲", systemImage: "wand.and.stars")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .disabled(vm.phase == .streaming)

            if vm.phase == .streaming {
                Button("停止", role: .destructive) { vm.stop() }
                    .font(.footnote)
                ProgressView().controlSize(.small)
            }
            Spacer()
        }

        if let error = vm.errorMessage {
            Label(error, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundColor(.red)
        }

        switch vm.phase {
        case .streaming:
            VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
                StreamingStatusView(tracker: vm.progress, showsOutputting: false)
                Text(vm.draft.isEmpty ? "正在生成本章细纲…" : vm.draft)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(10)
            }
        case .done where !vm.draft.isEmpty:
            VStack(spacing: AppTheme.spacing[1]) {
                draftCard
                if let parsed = vm.extractedSceneCards {
                    Label("已附 \(parsed.count) 张场景卡，采纳后填入场景卡编辑区", systemImage: "rectangle.stack")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        default:
            EmptyView()
        }
    }

    private var draftCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            Text(vm.draft)
                .font(.callout)
            if !vm.truncatedSections.isEmpty {
                Text("超预算裁剪：\(vm.truncatedSections.joined(separator: "、"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: AppTheme.spacing[1]) {
                Button {
                    acceptDraft()
                } label: {
                    Label("采纳", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    regenerate()
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    vm.reset()
                } label: {
                    Text("放弃")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func generate() {
        guard let novel = chapter.volume?.novel else {
            vm.errorMessage = "无法确定所属作品"
            return
        }
        guard let provider = store.defaultProvider else {
            vm.errorMessage = "尚未配置模型提供商，请先到设置页添加"
            return
        }
        let extra = aiInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        vm.start(kind: .chapter(chapter), novel: novel, provider: provider,
                 instruction: extra.isEmpty ? nil : extra)
    }

    private func regenerate() {
        guard let novel = chapter.volume?.novel else { return }
        guard let provider = store.defaultProvider else {
            vm.errorMessage = "尚未配置模型提供商，请先到设置页添加"
            return
        }
        vm.regenerate(novel: novel, provider: provider)
    }

    /// 采纳 = 细纲填入编辑区；若草稿附 zm-scene 则场景卡同步进卡片编辑区，均由「保存」统一落库
    private func acceptDraft() {
        outlineDraft = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = vm.extractedSceneCards {
            cards = parsed
        }
        vm.reset()
    }
}

/// 卷四维规划编辑：情绪走向 / 冲突阶梯 / 信息差（防抖保存，与卷纲一致）
private struct FourDimsEditor: View {
    @ObservedObject var store: AppStore
    @ObservedObject var volume: Volume

    @State private var expanded = false
    @State private var saveTask: Task<Void, Never>?

    private var hasAnyContent: Bool {
        !(volume.emotionArc ?? []).isEmpty
            || !(volume.conflictLadder ?? []).isEmpty
            || !(volume.infoGap?.isEmpty ?? true)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            emotionRows
            ladderRows
            infoGapRows
        } label: {
            Label("四维规划（情绪 / 冲突 / 信息差）", systemImage: "square.stack.3d.up.fill")
                .font(.footnote)
                .foregroundStyle(hasAnyContent ? Color.accentColor : Color.secondary)
        }
    }

    // MARK: 情绪走向

    private var emotionRows: some View {
        Group {
            ForEach((volume.emotionArc ?? []).indices, id: \.self) { index in
                HStack(spacing: AppTheme.spacing[1]) {
                    Text("拍\(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 32, alignment: .leading)
                    TextField("如：压抑 / 提升 / 打脸", text: arcBinding(index))
                        .font(.subheadline)
                    Button {
                        volume.emotionArc?.remove(at: index)
                        store.save()
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                volume.emotionArc = (volume.emotionArc ?? []) + ["提升"]
                store.save()
            } label: {
                Label("添加情绪拍", systemImage: "plus.circle")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 冲突阶梯

    private var ladderRows: some View {
        Group {
            let ladder = volume.conflictLadder ?? []
            ForEach(ladder.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppTheme.spacing[1]) {
                        Text("L\(ladder[index].level)")
                            .font(.caption2.bold())
                            .frame(width: 30, alignment: .leading)
                        TextField("该层阻力/对手", text: rungObstacleBinding(index))
                            .font(.subheadline)
                        Button(role: .destructive) {
                            removeRung(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("跨入该层的转折点（可选）", text: rungTurningBinding(index))
                        .font(.footnote)
                }
            }
            Button {
                let next = (volume.conflictLadder?.count ?? 0) + 1
                volume.conflictLadder = (volume.conflictLadder ?? []) + [ConflictRung(level: next, obstacle: "")]
                store.save()
            } label: {
                Label("添加冲突层", systemImage: "plus.circle")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 信息差

    private var infoGapRows: some View {
        Group {
            TextField("信息差 · 卷初谁知道什么", text: infoBinding(\.start))
                .font(.subheadline)
            TextField("信息差 · 卷末将揭示或颠覆什么", text: infoBinding(\.end))
                .font(.subheadline)
        }
    }

    // MARK: 绑定与保存

    private func arcBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { volume.emotionArc?[index] ?? "" },
            set: { volume.emotionArc?[index] = $0; scheduleSave() }
        )
    }

    private func rungObstacleBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { volume.conflictLadder?[index].obstacle ?? "" },
            set: { volume.conflictLadder?[index].obstacle = $0; scheduleSave() }
        )
    }

    private func rungTurningBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { volume.conflictLadder?[index].turningPoint ?? "" },
            set: {
                if volume.conflictLadder?[index] != nil {
                    volume.conflictLadder?[index].turningPoint = $0.isEmpty ? nil : $0
                }
                scheduleSave()
            }
        )
    }

    private func infoBinding(_ keyPath: WritableKeyPath<InfoGap, String>) -> Binding<String> {
        Binding(
            get: { volume.infoGap?[keyPath: keyPath] ?? "" },
            set: {
                if volume.infoGap == nil { volume.infoGap = InfoGap() }
                volume.infoGap?[keyPath: keyPath] = $0
                scheduleSave()
            }
        )
    }

    private func removeRung(at index: Int) {
        guard var ladder = volume.conflictLadder, ladder.indices.contains(index) else { return }
        ladder.remove(at: index)
        for i in ladder.indices { ladder[i].level = i + 1 }   // 层级自动重排
        volume.conflictLadder = ladder.isEmpty ? nil : ladder
        store.save()
    }

    /// 输入防抖保存（与卷纲编辑同一策略，避免逐键落盘）
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            store.save()
        }
    }
}

/// 伏笔台账：AI 自动提取的伏笔加手动新增，统一在此管理状态与回收
private struct ForeshadowDashboardSection: View {
    @ObservedObject var store: AppStore
    @ObservedObject var novel: Novel

    @State private var expanded = false
    @State private var editing: Foreshadowing?
    @State private var showAdd = false
    @State private var deleting: Foreshadowing?

    /// 未回收数量
    private var openCount: Int {
        novel.foreshadowings.filter { $0.status == .open }.count
    }

    /// 按状态排序（未回收→已回收→废弃），同级按埋设位置
    private var sorted: [Foreshadowing] {
        novel.foreshadowings.sorted {
            $0.statusSortRank != $1.statusSortRank
                ? $0.statusSortRank < $1.statusSortRank
                : ($0.plantedVolumeIndex ?? 0, $0.plantedChapterOrder ?? 0) < ($1.plantedVolumeIndex ?? 0, $1.plantedChapterOrder ?? 0)
        }
    }

    var body: some View {
        Section {
            if novel.foreshadowings.isEmpty {
                Text("暂无伏笔记录。AI 会在生成章节摘要时自动提取新伏笔，你也可以手动添加。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted) { foreshadowing in
                    row(for: foreshadowing)
                }
                Button {
                    showAdd = true
                } label: {
                    Label("手动新增伏笔", systemImage: "plus.circle").font(.footnote)
                }
            }
        } header: {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Label("伏笔台账", systemImage: "eye").font(.footnote)
                    Spacer()
                    if openCount > 0 {
                        Text("\(openCount) 未回收")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAdd) {
            ForeshadowEditSheet(novel: novel)
        }
        .sheet(item: $editing) { item in
            ForeshadowEditSheet(novel: novel, existing: item)
        }
    }

    /// 单条伏笔行
    private func row(for foreshadowing: Foreshadowing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if foreshadowing.suggestedResolved && foreshadowing.status == .open {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
                Text(foreshadowing.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(foreshadowing.status.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(foreshadowing.status.tintColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(foreshadowing.status.tintColor)
            }
            HStack {
                Text(positionText(for: foreshadowing))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let planned = foreshadowing.plannedResolve, !planned.isEmpty {
                    Text("计划回收：\(planned)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            if deleting?.id == foreshadowing.id {
                InlineConfirmCard(
                    title: "删除「\(foreshadowing.title)」？",
                    message: "此伏笔记录将被永久移除，无法恢复。",
                    confirmLabel: "确认删除",
                    onConfirm: {
                        novel.foreshadowings.removeAll { $0.id == foreshadowing.id }
                        deleting = nil
                        store.save()
                    },
                    onCancel: { deleting = nil }
                )
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { editing = foreshadowing }
        // 普通视图 + 直接挂 contextMenu，避开 Button+contextMenu 在 iOS 15 的菜单错配
        .contextMenu {
            Button {
                editing = foreshadowing
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            if foreshadowing.status != .resolved {
                Button {
                    flip(foreshadowing, to: .resolved)
                } label: {
                    Label("标记为已回收", systemImage: "checkmark.circle")
                }
            }
            if foreshadowing.status != .dropped {
                Button {
                    flip(foreshadowing, to: .dropped)
                } label: {
                    Label("废弃此伏笔", systemImage: "trash.slash")
                }
            }
            Divider()
            Button(role: .destructive) {
                deleting = foreshadowing
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    /// 快速切换状态
    private func flip(_ f: Foreshadowing, to newStatus: ForeshadowStatus) {
        guard let index = novel.foreshadowings.firstIndex(where: { $0.id == f.id }) else { return }
        novel.foreshadowings[index].status = newStatus
        novel.foreshadowings[index].suggestedResolved = false
        store.save()
    }

    /// 埋设位置文本
    private func positionText(for f: Foreshadowing) -> String {
        if let v = f.plantedVolumeIndex, let c = f.plantedChapterOrder {
            return "第\(v)卷第\(c)章"
        }
        return "位置未知"
    }
}

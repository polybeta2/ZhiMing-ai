#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 档案详情：风格卡（名称/标签/小结/规则/示例）可编辑，七层机制明细只读展示。
/// 采用「本地副本 + 保存按钮」模式（与 SummaryEditSheet 一致），避免逐键写库。
struct StyleProfileDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profile: StyleProfile

    @State private var name: String
    @State private var tagsText: String
    @State private var summary: String
    @State private var mustRules: [String]
    @State private var avoidRules: [String]
    @State private var dirty = false
    @State private var showDelete = false
    @State private var showAugment = false

    init(profile: StyleProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _tagsText = State(initialValue: profile.tags.joined(separator: "，"))
        _summary = State(initialValue: profile.fingerprintSummary)
        _mustRules = State(initialValue: profile.mustRules)
        _avoidRules = State(initialValue: profile.avoidRules)
    }

    var body: some View {
        Form {
            styleCardSection
            examplesSection
            layersSection
            metricsSection
            correctionsSection
            infoSection
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!dirty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showDelete) {
            DeleteConfirmSheet(title: "删除「\(profile.name)」？", message: "删除后不可恢复。") {
                store.deleteStyleProfile(profile)
                dismiss()
            }
        }
        .sheet(isPresented: $showAugment) {
            StyleDistillSheet(augmentTarget: profile)
        }
        .onDisappear { if dirty { save() } }
    }

    // MARK: 风格卡（可编辑）

    private var styleCardSection: some View {
        Section("风格卡") {
            TextField("档案名称", text: $name)
                .onChange(of: name) { _ in dirty = true }
            TextField("标签（逗号分隔）", text: $tagsText)
                .onChange(of: tagsText) { _ in dirty = true }
            MultilineField(text: $summary, placeholder: "风格指纹小结…", minHeight: 80)
                .onChange(of: summary) { _ in dirty = true }
            StringListEditor(title: "必遵规则", items: $mustRules) { dirty = true }
            StringListEditor(title: "反面清单", items: $avoidRules) { dirty = true }
            Button {
                showAugment = true
            } label: {
                Label("追加样本再蒸馏…", systemImage: "arrow.triangle.merge")
            }
        }
    }

    // MARK: 示例对照（只读展示；示例由蒸馏生成并经查重）

    private var examplesSection: some View {
        Section("示范对照") {
            if profile.examples.isEmpty {
                Text("（无）").foregroundStyle(.secondary)
            }
            ForEach(profile.examples) { example in
                VStack(alignment: .leading, spacing: 4) {
                    Text("普通：\(example.plain)").font(.footnote).foregroundStyle(.secondary)
                    Text("该文风：\(example.styled)").font(.footnote)
                    if !example.principle.isEmpty {
                        Text("机制：\(example.principle)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: 七层机制（只读明细）

    private var layersSection: some View {
        Section("机制明细") {
            ForEach(layerRows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0).font(.footnote).foregroundStyle(.secondary).frame(width: 76, alignment: .leading)
                    Text(row.1).font(.footnote)
                }
            }
            ForEach(profile.evidence) { evidence in
                VStack(alignment: .leading, spacing: 2) {
                    Text("证据：\(evidence.trait)").font(.caption2)
                    Text("「\(evidence.snippet)」(\(evidence.confidence))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var layerRows: [(String, String)] {
        var rows: [(String, String)] = []
        let v = profile.narrativeVoice
        if let s = v.pov, !s.isEmpty { rows.append(("视角", s)) }
        if let s = v.distance, !s.isEmpty { rows.append(("距离", s)) }
        if let s = v.temperature, !s.isEmpty { rows.append(("温度", s)) }
        if let s = v.interiority, !s.isEmpty { rows.append(("内心戏", s)) }
        if !v.cameraHabits.isEmpty { rows.append(("镜头习惯", v.cameraHabits.joined(separator: "；"))) }
        let syn = profile.sentenceSyntax
        if let s = syn.shape, !s.isEmpty { rows.append(("句型", s)) }
        if let s = syn.longShortRatio, !s.isEmpty { rows.append(("长短句", s)) }
        if let s = syn.punctuationRhythm, !s.isEmpty { rows.append(("标点", s)) }
        if !syn.signatureMoves.isEmpty { rows.append(("招牌句式", syn.signatureMoves.joined(separator: "；"))) }
        let d = profile.diction
        if let s = d.register, !s.isEmpty { rows.append(("语域", s)) }
        if !d.lexicalFields.isEmpty { rows.append(("词汇场", d.lexicalFields.joined(separator: "、"))) }
        if let s = d.sensoryWeights, !s.isEmpty { rows.append(("五感", s)) }
        if !d.bannedMoves.isEmpty { rows.append(("套话禁忌", d.bannedMoves.joined(separator: "、"))) }
        let r = profile.sceneRhythm
        if let s = r.openings, !s.isEmpty { rows.append(("开场", s)) }
        if let s = r.closings, !s.isEmpty { rows.append(("收束", s)) }
        if let s = r.actInnerEnvRatio, !s.isEmpty { rows.append(("三比", s)) }
        let dg = profile.dialogue
        if let s = dg.subtextLevel, !s.isEmpty { rows.append(("潜台词", s)) }
        if let s = dg.tagHabits, !s.isEmpty { rows.append(("标签", s)) }
        let e = profile.emotion
        if let s = e.directness, !s.isEmpty { rows.append(("情绪", s)) }
        if !e.preferredCarriers.isEmpty { rows.append(("载体", e.preferredCarriers.joined(separator: "、"))) }
        if !profile.antiAI.forbiddenPatterns.isEmpty {
            rows.append(("AI腔禁忌", profile.antiAI.forbiddenPatterns.joined(separator: "；")))
        }
        return rows
    }

    // MARK: 计量与来源（只读）

    private var metricsSection: some View {
        Section("本地计量") {
            if let m = profile.localMetrics {
                Text("""
                句子 \(m.sentenceCount) 句 · 中位句长 \(Int(m.medianSentenceLength)) 字
                短句 \(Int(m.shortSentenceRatio * 100))% · 长句 \(Int(m.longSentenceRatio * 100))% · 长短变化率 \(Int(m.alternationRate * 100))%
                对话行 \(Int(m.dialogueLineRatio * 100))% · 破折号/千字 \(String(format: "%.1f", m.dashPer1k)) · 省略号/千字 \(String(format: "%.1f", m.ellipsisPer1k))
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("（无）").foregroundStyle(.secondary)
            }
        }
    }

    private var infoSection: some View {
        Section("档案信息") {
            LabeledRow(label: "来源", value: profile.sourceNote.isEmpty ? "（未填写）" : profile.sourceNote)
            LabeledRow(label: "样本字数", value: "\(profile.sampleCharCount)")
            LabeledRow(label: "置信度", value: profile.confidence)
        }
    }

    // MARK: 修正日志（追加样本/人工调整的历史，最新在后）

    private var correctionsSection: some View {
        Section("修正记录") {
            if profile.corrections.isEmpty {
                Text("（无）").foregroundStyle(.secondary)
            }
            ForEach(Array(profile.corrections.suffix(10).reversed())) { correction in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(correction.field)：\(correction.before) → \(correction.after)")
                        .font(.caption2)
                    Text("\(correction.reason) · \(correction.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if profile.corrections.count > 10 {
                Text("（仅显示最近 10 条，共 \(profile.corrections.count) 条）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { profile.name = trimmedName }
        profile.tags = FlexStringArray.splitList(tagsText)
        profile.fingerprintSummary = summary
        profile.mustRules = mustRules
        profile.avoidRules = avoidRules
        store.upsertStyleProfile(profile)
        dirty = false
    }
}

/// 简单「标签: 值」行（iOS 15 无 LabeledContent）
private struct LabeledRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

/// 通用字符串列表编辑器（增删改一行一条）
struct StringListEditor: View {
    let title: String
    @Binding var items: [String]
    let onChange: () -> Void
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    MultilineField(
                        text: Binding(
                            get: { items[index] },
                            set: { items[index] = $0; onChange() }
                        ),
                        placeholder: "规则 \(index + 1)",
                        minHeight: 20,
                        maxLines: 3
                    )
                    Button {
                        items.remove(at: index)
                        onChange()
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("添加新条目", text: $newItem)
                Button {
                    let trimmed = newItem.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    items.append(trimmed)
                    newItem = ""
                    onChange()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
#endif

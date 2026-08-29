#if os(iOS) || os(macOS)
import SwiftUI
import ZhiMingCore

/// 多档案按层融合向导：基底档案（小结/规则/示范来源）+ 六层各选来源。
/// 参与档案 = 风格库全部档案（至少 2 份）；产出全新档案入库。
struct StyleFusionSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var baseID: UUID?
    @State private var voiceID: UUID?
    @State private var syntaxID: UUID?
    @State private var dictionID: UUID?
    @State private var rhythmID: UUID?
    @State private var dialogueID: UUID?
    @State private var emotionID: UUID?

    private var profiles: [StyleProfile] { store.styleProfiles }
    private var base: StyleProfile? { profiles.first { $0.id == baseID } }

    private var fused: StyleProfile? {
        guard let baseID, let base = base,
              let voice = voiceID ?? baseID,
              let syntax = syntaxID ?? baseID,
              let diction = dictionID ?? baseID,
              let rhythm = rhythmID ?? baseID,
              let dialogue = dialogueID ?? baseID,
              let emotion = emotionID ?? baseID else { return nil }
        return StyleFusion.fuse(
            name: name.isEmpty ? "融合文风" : name,
            base: base,
            participants: profiles,
            choices: .init(voice: voice, syntax: syntax, diction: diction,
                           rhythm: rhythm, dialogue: dialogue, emotion: emotion))
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("产出档案") {
                    TextField("融合档案名称（4-10字）", text: $name)
                    Picker("基底（小结/规则/示范）", selection: $baseID) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(UUID?.some(profile.id))
                        }
                    }
                    .onChange(of: baseID) { _ in
                        // 换基底时六层跟随重置为基底，避免遗留失效选择
                        voiceID = baseID
                        syntaxID = baseID
                        dictionID = baseID
                        rhythmID = baseID
                        dialogueID = baseID
                        emotionID = baseID
                    }
                }
                Section(footer: Text("反AI禁令、禁用套话与标签/规则自动取全体并集；示范对照与指纹小结取基底档案。")) {
                    layerPicker("叙事声音", $voiceID)
                    layerPicker("句法节奏", $syntaxID)
                    layerPicker("词汇质地", $dictionID)
                    layerPicker("场景节奏", $rhythmID)
                    layerPicker("对白方式", $dialogueID)
                    layerPicker("情绪处理", $emotionID)
                }
                if let fused {
                    Section("预览") {
                        LabeledRowCompat(label: "标签", value: fused.tags.joined(separator: "、"))
                        LabeledRowCompat(label: "必遵规则", value: "\(fused.mustRules.count) 条")
                        LabeledRowCompat(label: "反AI禁令", value: "\(fused.antiAI.forbiddenPatterns.count) 条")
                        Text(fused.fingerprintSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("融合文风档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成并入库") {
                        guard let fused else { return }
                        store.upsertStyleProfile(fused)
                        dismiss()
                    }
                    .disabled(fused == nil)
                }
            }
        }
        .onAppear {
            if baseID == nil, let first = profiles.first {
                baseID = first.id
                voiceID = first.id
                syntaxID = first.id
                dictionID = first.id
                rhythmID = first.id
                dialogueID = first.id
                emotionID = first.id
            }
        }
    }

    private func layerPicker(_ title: String, _ selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            ForEach(profiles) { profile in
                Text(profile.name).tag(UUID?.some(profile.id))
            }
        }
    }
}

private struct LabeledRowCompat: View {
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
#endif

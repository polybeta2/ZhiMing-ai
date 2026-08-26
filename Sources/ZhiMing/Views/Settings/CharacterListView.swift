import SwiftUI

/// 角色卡列表（含「当前状态列」，借鉴司命 characters 表）
struct CharacterListView: View {
    @EnvironmentObject private var store: AppStore
    let novel: Novel
    @State private var editing: CharacterCard?
    @State private var showNew = false
    @State private var deleting: CharacterCard?

    var body: some View {
        List {
            if novel.characters.isEmpty {
                Section {
                    Text("还没有角色。添加角色卡后，标记「参与近期剧情」的角色会在续写时进入上下文。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(novel.characters) { character in
                Button {
                    editing = character
                } label: {
                    CharacterRow(character: character)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleting = character
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("角色卡")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) {
            CharacterEditView(novel: novel, character: nil)
        }
        .sheet(item: $editing) { character in
            CharacterEditView(novel: novel, character: character)
        }
        // 删除确认用 sheet 内嵌卡（系统弹窗按钮动作不可靠，v1.5.2 教训）
        .sheet(item: $deleting) { character in
            VStack(spacing: AppTheme.spacing[2]) {
                InlineConfirmCard(
                    title: "删除角色「\(character.name)」？",
                    message: "该角色的全部字段将移除，无法恢复。",
                    confirmLabel: "确认删除",
                    onConfirm: {
                        novel.characters.removeAll { $0.id == character.id }
                        store.save()
                        deleting = nil
                    },
                    onCancel: { deleting = nil }
                )
                Spacer()
            }
            .padding(AppTheme.spacing[3])
        }
    }
}

private struct CharacterRow: View {
    @ObservedObject var character: CharacterCard

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            ZStack(alignment: .center) {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Text(String(character.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(character.name).font(.headline)
                    if !character.isSceneRelevant {
                        Text("暂离剧情")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(statusLine.isEmpty ? "未填写当前状态" : statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, AppTheme.spacing[0])
        .contentShape(Rectangle())
    }

    private var statusLine: String {
        var parts: [String] = []
        if let v = character.currentLocation, !v.isEmpty { parts.append("在\(v)") }
        if let v = character.currentGoal, !v.isEmpty { parts.append(v) }
        return parts.joined(separator: " · ")
    }
}

#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 开发者功能面板：内置提示词编辑（改后立即生效）+ 示例标签库管理。
/// 入口在设置页，进入前有强提醒对话框（见 SettingsView）。
struct DeveloperPanelView: View {
    @ObservedObject private var library = PromptLibrary.shared

    /// 内置提示词按分类分组展示（保持定义顺序）
    private var groupedPrompts: [(category: String, prompts: [BuiltInPrompt])] {
        var seen = Set<String>()
        var result: [(category: String, prompts: [BuiltInPrompt])] = []
        for prompt in library.builtInPrompts where !seen.contains(prompt.category) {
            seen.insert(prompt.category)
            result.append((
                category: prompt.category,
                prompts: library.builtInPrompts.filter { $0.category == prompt.category }
            ))
        }
        return result
    }

    var body: some View {
        List {
            Section {
                Text("此处修改保存后立即对后续所有 AI 请求生效；「已自定义」表示当前文本与出厂默认不同，可随时恢复默认。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(groupedPrompts, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.prompts) { prompt in
                        NavigationLink(destination: PromptEditView(prompt: prompt)) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(prompt.name).font(.subheadline)
                                    if library.isCustomized(prompt.id) {
                                        Text("已自定义")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text(library.resolvedText(for: prompt.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }

            tagLibrarySections
        }
        .navigationTitle("开发者功能")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 示例标签库管理

    private var tagLibrarySections: some View {
        Section(footer: Text("标签供「一句话立项」使用：用户启用且输入命中关键词时注入预设内容。可增删改；删除不影响已创建作品。")) {
            ForEach(library.tagCategories) { category in
                DisclosureGroup {
                    ForEach(category.tags) { tag in
                        NavigationLink(destination: TagEditView(categoryId: category.id, existingTag: tag)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.name).font(.subheadline)
                                Text(tag.keywords.joined(separator: "、"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    NavigationLink(destination: TagEditView(categoryId: category.id, existingTag: nil)) {
                        Label("新建标签", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                } label: {
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text("\(category.tags.count) 个")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 提示词编辑页

struct PromptEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = PromptLibrary.shared
    let prompt: BuiltInPrompt

    @State private var text = ""
    @State private var loaded = false
    @State private var showResetConfirm = false

    private var isModified: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            != prompt.defaultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section(footer: Text(footerText)) {
                MultilineField(text: $text, placeholder: "提示词内容", minHeight: 260)
                    .font(.callout)
                HStack {
                    Spacer()
                    Text("\(text.count) / \(PromptLimits.maxOverrideChars)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(text.count > PromptLimits.maxOverrideChars ? .red : .secondary)
                }
            }
            Section {
                if showResetConfirm {
                    // 内联两步确认（不用系统弹窗：部分系统版本 alert 按钮动作不可靠）
                    Text("将丢弃该提示词的全部自定义内容，恢复为出厂版本。")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button(role: .destructive) {
                        library.resetOverride(prompt.id)
                        text = prompt.defaultText
                        showResetConfirm = false
                    } label: {
                        Label("确认恢复出厂默认", systemImage: "arrow.counterclockwise")
                    }
                    Button("取消") { showResetConfirm = false }
                } else {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("恢复出厂默认", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!library.isCustomized(prompt.id) && !isModified)
                }
            } footer: {
                Text("恢复操作会丢弃你的全部自定义内容。")
            }
        }
        .navigationTitle(prompt.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    library.setOverride(prompt.id, text: text)
                    dismiss()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = library.resolvedText(for: prompt.id)
        }
    }

    private var placeholders: [String] { prompt.placeholders }

    private var footerText: String {
        let base = placeholders.isEmpty
            ? "此模板无占位符，可直接整段改写。"
            : "可用占位符（发送时自动替换）：\(placeholders.joined(separator: "；"))"
        return base + " 上限 \(PromptLimits.maxOverrideChars) 字，保存时超长部分自动截断（覆盖文本会原样进入每次请求）。"
    }
}

// MARK: - 标签新增/编辑页

struct TagEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = PromptLibrary.shared

    let categoryId: String
    let existingTag: PromptTag?      // nil = 新建

    @State private var name = ""
    @State private var keywordsText = ""
    @State private var presetText = ""
    @State private var loaded = false
    @State private var showDeleteConfirm = false

    private var category: PromptTagCategory? {
        library.tagCategories.first(where: { $0.id == categoryId })
    }

    private var parsedKeywords: [String] {
        keywordsText
            .split(whereSeparator: { ",，".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !presetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("标签名（如：赛博朋克）", text: $name)
                TextField("触发关键词（逗号分隔，含标签名可不填）", text: $keywordsText)
            }
            Section(footer: Text("用户启用该标签且创意输入命中任一关键词时，这段内容会作为创作方向约束拼入蓝图生成的系统提示词。上限 \(PromptLimits.maxTagPresetChars) 字，保存时超长部分自动截断；多条命中标签的合计注入量另有 \(PromptLimits.matchedSupplementCap) 字熔断。")) {
                MultilineField(text: $presetText, placeholder: "完整预设提示词内容…", minHeight: 200)
                HStack {
                    Spacer()
                    Text("\(presetText.count) / \(PromptLimits.maxTagPresetChars)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(presetText.count > PromptLimits.maxTagPresetChars ? .red : .secondary)
                }
            }
            if existingTag != nil {
                Section {
                    if showDeleteConfirm {
                        // 内联两步确认（不用系统弹窗：部分系统版本 alert 按钮动作不可靠）
                        Text("「\(existingTag?.name ?? "")」将从分类中移除；已启用它的旧作品不再注入其内容。")
                            .font(.caption)
                            .foregroundColor(.red)
                        Button(role: .destructive) {
                            if let tag = existingTag {
                                library.deleteTag(tag, categoryId: categoryId)
                            }
                            dismiss()
                        } label: {
                            Label("确认删除", systemImage: "trash")
                        }
                        Button("取消") { showDeleteConfirm = false }
                    } else {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除该标签", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(existingTag == nil ? "新建标签" : "编辑标签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            guard let tag = existingTag else { return }
            name = tag.name
            keywordsText = tag.keywords.joined(separator: "，")
            presetText = tag.presetText
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        // 关键词去重；标签名本身由匹配逻辑天然覆盖，无需强制写入
        var keywords = parsedKeywords
        if !keywords.contains(trimmedName) {
            keywords.insert(trimmedName, at: 0)
        }
        let id = existingTag?.id ?? "tag.\(UUID().uuidString.lowercased().prefix(8))"
        let tag = PromptTag(
            id: id,
            name: trimmedName,
            keywords: keywords,
            presetText: presetText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        library.upsertTag(tag, categoryId: categoryId)
        dismiss()
    }
}
#endif

import Foundation
import Combine

// MARK: - 蓝图结构（字段与 creationBlueprint 模板一一对应）

struct BlueprintCharacter: Codable, Identifiable {
    var id = UUID()
    var name: String?
    var role: String?
    var appearance: String?
    var personality: String?
    var goal: String?

    enum CodingKeys: String, CodingKey { case name, role, appearance, personality, goal }
}

struct BlueprintWorld: Codable, Identifiable {
    var id = UUID()
    var category: String?
    var name: String?
    var content: String?

    enum CodingKeys: String, CodingKey { case category, name, content }
}

struct BlueprintChapter: Codable, Identifiable {
    var id = UUID()
    var title: String?
    var detailed_outline: String?

    enum CodingKeys: String, CodingKey { case title, detailed_outline }
}

struct BlueprintVolume: Codable, Identifiable {
    var id = UUID()
    var name: String?
    var outline: String?
    var chapters: [BlueprintChapter] = []

    enum CodingKeys: String, CodingKey { case name, outline, chapters }
}

struct NovelBlueprint: Codable {
    var title_suggestion: String?
    var theme: String?
    var synopsis: String?
    var perspective: String?
    var style_guide: String?
    var characters: [BlueprintCharacter] = []
    var worldbuilding: [BlueprintWorld] = []
    var volumes: [BlueprintVolume] = []
}

// MARK: - 立项会话状态机

/// collecting → blueprint(streaming) → revising → confirmed
/// iOS 15 兼容：ObservableObject + @Published
@MainActor
final class CreationSessionViewModel: ObservableObject {
    enum Phase: Equatable { case collecting, streaming, revising, confirmed }

    @Published private(set) var phase: Phase = .collecting
    @Published var blueprint: NovelBlueprint?
    @Published private(set) var draft = ""
    @Published var errorMessage: String?
    /// 流结束后回调：(原始输出, 是否解析成功)。取消/失败时也会触发。
    var onStreamSettled: ((_ raw: String, _ parsed: Bool) -> Void)?
    private var streamTask: Task<Void, Never>?

    // MARK: 生成蓝图

    func generateBlueprint(brief: String, provider: ProviderConfig, supplement: String? = nil) {
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }
        phase = .streaming
        draft = ""
        errorMessage = nil
        KeepAwake.set(true)

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationBlueprint(brief: brief, supplement: supplement)
        )
        stream(messages: messages, client: client, config: config)
    }

    // MARK: 对话修订

    func revise(feedback: String, provider: ProviderConfig) {
        guard let json = blueprintJSON() else {
            errorMessage = "当前没有可修订的蓝图"
            phase = .collecting
            return
        }
        guard let apiKey = KeychainHelper.load(account: provider.apiKeyID),
              let baseUrl = URL(string: provider.baseUrl) else {
            errorMessage = "未配置有效的模型接口或 API Key"
            return
        }
        phase = .streaming
        draft = ""
        errorMessage = nil
        KeepAwake.set(true)

        let client = OpenAICompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: provider.modelName)
        let config = GenerationConfig(temperature: provider.temperature, maxTokens: provider.maxTokens)
        let messages = PromptTemplates.applying(
            providerExtra: provider.systemPromptExtra,
            to: PromptTemplates.creationRevise(blueprintJSON: json, feedback: feedback)
        )
        stream(messages: messages, client: client, config: config)
    }

    func stop() { streamTask?.cancel() }

    /// 供对话修订时携带当前蓝图
    func blueprintJSON() -> String? {
        guard let blueprint else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(blueprint) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: 确认创建

    /// 把蓝图写入数据层：Novel + 角色 + 世界观 + 卷/章/细纲
    func confirm(into novel: Novel, store: AppStore) {
        guard let blueprint else { return }

        if let title = blueprint.title_suggestion?.trimmingCharacters(in: .whitespaces), !title.isEmpty {
            novel.title = title
        }
        if let synopsis = blueprint.synopsis?.trimmingCharacters(in: .whitespaces), !synopsis.isEmpty {
            novel.synopsis = synopsis
        }
        novel.perspective = blueprint.perspective?.isEmpty == false ? blueprint.perspective : novel.perspective
        novel.styleGuide = blueprint.style_guide?.isEmpty == false ? blueprint.style_guide : novel.styleGuide
        novel.genre = blueprint.theme?.isEmpty == false ? blueprint.theme : novel.genre
        novel.updatedAt = .now

        // 角色
        novel.characters = []
        for item in blueprint.characters {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty else { continue }
            let card = CharacterCard(name: name)
            card.appearance = item.appearance
            card.personality = item.personality
            card.currentGoal = item.goal
            if let role = item.role, !role.isEmpty {
                card.background = "书中定位：\(role)"
            }
            card.isSceneRelevant = true
            card.novel = novel
            novel.characters.append(card)
        }

        // 世界观
        novel.worldEntries = []
        let validCategories = Set(WorldListView.categories)
        for item in blueprint.worldbuilding {
            let name = item.name?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty else { continue }
            let category = validCategories.contains(item.category ?? "") ? item.category! : "其他"
            let entry = WorldEntry(category: category, name: name, content: item.content ?? "")
            entry.novel = novel
            novel.worldEntries.append(entry)
        }

        // 卷与章
        novel.volumes = []
        for (volumeIndex, item) in blueprint.volumes.enumerated() {
            let volume = Volume(
                name: item.name?.isEmpty == false ? item.name! : "第\(volumeIndex + 1)卷",
                sortOrder: volumeIndex + 1,
                outline: item.outline
            )
            volume.novel = novel
            for (chapterIndex, chapterItem) in item.chapters.enumerated() {
                let chapter = Chapter(
                    title: chapterItem.title?.isEmpty == false ? chapterItem.title! : "第\(chapterIndex + 1)章",
                    sortOrder: chapterIndex + 1
                )
                chapter.detailedOutline = chapterItem.detailed_outline
                chapter.volume = volume
                volume.chapters.append(chapter)
            }
            novel.volumes.append(volume)
        }

        phase = .confirmed
        store.save()
    }

    // MARK: 内部

    private func stream(
        messages: [LLMMessage],
        client: OpenAICompatibleClient,
        config: GenerationConfig
    ) {
        streamTask?.cancel()
        streamTask = Task {
            // 流式节流：delta 先进缓冲，约 100ms 刷新一次发布属性，避免逐字重渲染卡顿
            var raw = ""
            var lastFlush = Date.distantPast
            do {
                for try await delta in client.streamChat(messages: messages, config: config) {
                    raw += delta
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.1 {
                        self.draft = raw
                        lastFlush = now
                    }
                }
                if !Task.isCancelled {
                    self.draft = raw
                    let parsed = self.finalize(raw)
                    self.onStreamSettled?(raw, parsed)
                }
            } catch is CancellationError {
                // 停止：把已生成的部分交给界面保留
                self.draft = raw
                self.errorMessage = raw.isEmpty ? nil : "生成被停止，已保留部分结果"
                self.phase = self.blueprint == nil ? .collecting : .revising
                self.onStreamSettled?(raw, false)
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.phase = self.blueprint == nil ? .collecting : .revising
                    self.onStreamSettled?("", false)
                }
            }
            self.draft = ""
            KeepAwake.set(false)
        }
    }

    private func finalize(_ raw: String) -> Bool {
        if let parsed = LLMJSONParser.decode(NovelBlueprint.self, fromJSONObjectIn: raw) {
            blueprint = parsed
            errorMessage = nil
            phase = .revising
            return true
        } else {
            // 解析失败：原始回复已在聊天中展示，提示重试（不做静默降级）
            errorMessage = "蓝图 JSON 解析失败，可发送「重新生成」"
            phase = .collecting
            return false
        }
    }
}

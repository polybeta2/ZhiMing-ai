#if os(iOS) || os(macOS)
import Foundation
import Combine
import ZhiMingCore

/// 自动撰写流水线：从第一个空白章开始，依次「撰写 → 建档 → 下一章」。
/// 建档（摘要+关键事实+伏笔登记）是关键步骤——下一章的上下文靠它拿到叙事账本。
/// 每章完成即 store.save()（防抖之外的强制落盘），中断只损失当前章。
/// 明确不做的体量确认：PromptGuard 是交互式弹窗，自动流水线绕过（界面已提示风险）。
@MainActor
final class AutoWriteViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle, writing, archiving, done, stopped, failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var currentChapterTitle = ""
    @Published private(set) var doneCount = 0
    @Published private(set) var totalTarget = 0
    @Published private(set) var completedTitles: [String] = []
    let progress = StreamProgressTracker()

    private weak var store: AppStore?
    private var task: Task<Void, Never>?

    var isRunning: Bool { phase == .writing || phase == .archiving }

    /// 待写章节 = 全书顺序中正文为空的章（跳过已手写的中间章，顺序补齐其后空白章）
    static func pendingChapters(in novel: Novel) -> [Chapter] {
        guard allOutlinesReady(in: novel) else { return [] }
        return novel.allChaptersInOrder.filter {
            $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 自动撰写门槛：全书每章都有细纲
    static func allOutlinesReady(in novel: Novel) -> Bool {
        let chapters = novel.allChaptersInOrder
        guard !chapters.isEmpty else { return false }
        return chapters.allSatisfy {
            !($0.detailedOutline ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func start(store: AppStore, novel: Novel, provider: ProviderConfig,
               wordTarget: Int, antiAIInline: Bool) {
        guard !isRunning else { return }
        let targets = Self.pendingChapters(in: novel)
        guard !targets.isEmpty else {
            phase = .failed("没有待写的空白章节")
            return
        }
        totalTarget = targets.count
        doneCount = 0
        completedTitles = []
        self.store = store
        phase = .writing
        task = Task { [weak self] in
            for chapter in targets {
                if Task.isCancelled { self?.finish(.stopped); return }
                guard let self else { return }

                // 1) 撰写本章
                self.currentChapterTitle = chapter.title
                self.phase = .writing
                guard await self.writeChapter(chapter, novel: novel, provider: provider,
                                              wordTarget: wordTarget, antiAIInline: antiAIInline) else { return }
                if Task.isCancelled { self.finish(.stopped); return }

                // 2) 建档（下一章上下文的叙事账本来源）
                self.phase = .archiving
                guard await self.archiveChapter(chapter, novel: novel, provider: provider) else { return }
                if Task.isCancelled { self.finish(.stopped); return }

                self.doneCount += 1
                self.completedTitles.append(chapter.title)
                store.save()
            }
            guard let self else { return }
            self.finish(.done)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        progress.finish()
        if isRunning { phase = .stopped }
    }

    private func finish(_ phase: Phase) {
        progress.finish()
        self.phase = phase
    }

    var statusLabel: String {
        switch phase {
        case .idle: return "准备中"
        case .writing: return "撰写《\(currentChapterTitle)》…"
        case .archiving: return "建档《\(currentChapterTitle)》…"
        case .done: return "自动撰写完成（\(doneCount)/\(totalTarget)）"
        case .stopped: return "已停止（完成 \(doneCount)/\(totalTarget)，已写章节均已保存）"
        case .failed(let message): return message
        }
    }

    // MARK: 撰写单章（与 WritingSessionViewModel.start(.writing) 同一装配契约）

    private func writeChapter(_ chapter: Chapter, novel: Novel, provider: ProviderConfig,
                              wordTarget: Int, antiAIInline: Bool) async -> Bool {
        let r18Text: String? = novel.r18Enabled
            ? PromptLibrary.shared.r18Supplement(forInput: String(chapter.content.prefix(400)))
            : nil
        let styleCard = novel.styleProfileCard(in: store?.styleProfiles ?? [], variant: .writing)
        let antiAIText = antiAIInline ? PromptLibrary.shared.resolvedText(for: PromptID.antiAIInline) : nil
        let budget = PromptTemplates.adjustedInputBudget(
            base: provider.contextBudgetChars,
            injections: r18Text, styleCard, antiAIText, provider.systemPromptExtra)
        let context = ContextBuilder.buildContinueContext(chapter: chapter, novel: novel,
                                                          budgetChars: budget, styleCard: styleCard)
        var messages = PromptTemplates.writing(context: context, wordTarget: wordTarget, extra: nil)
        if let r18 = r18Text { messages = PromptTemplates.applying(providerExtra: r18, to: messages) }
        if let antiAI = antiAIText { messages = PromptTemplates.applying(providerExtra: antiAI, to: messages) }
        messages = PromptTemplates.applying(providerExtra: provider.systemPromptExtra, to: messages)

        progress.begin()
        var draft = ""
        do {
            let client = Self.client(for: provider)
            for try await event in client.streamChat(messages: messages, config: config) {
                if case .content(let delta) = event {
                    draft += delta
                    progress.handle(event)
                }
                if Task.isCancelled { break }
            }
        } catch is CancellationError {
            finish(.stopped)
            return false
        } catch {
            finish(.failed("撰写《\(chapter.title)》失败：\(error.localizedDescription)。已写章节均已保存。"))
            return false
        }
        guard !Task.isCancelled else { finish(.stopped); return false }

        // 产出护栏：过短成文视为失败（多半是截断/拒答），不落正文
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 200 else {
            finish(.failed("《\(chapter.title)》输出过短（\(trimmed.count) 字），已停止。可重试或到编辑器单章撰写。"))
            return false
        }
        SnapshotService.snapshot(chapter, trigger: "ai_insert")
        chapter.content += draft
        chapter.wordCount = chapter.content.count
        chapter.updatedAt = .now
        return true
    }

    // MARK: 建档单章（与 ChapterEditorView.generateSummary/applySummaryResult 同契约）

    private func archiveChapter(_ chapter: Chapter, novel: Novel, provider: ProviderConfig) async -> Bool {
        let messages = PromptTemplates.summarize(content: chapter.content, title: chapter.title)
        progress.begin()
        var raw = ""
        do {
            let client = Self.client(for: provider)
            for try await event in client.streamChat(messages: messages, config: config) {
                if case .content(let delta) = event {
                    raw += delta
                    progress.handle(event)
                }
                if Task.isCancelled { break }
            }
        } catch is CancellationError {
            finish(.stopped)
            return false
        } catch {
            finish(.failed("建档《\(chapter.title)》失败：\(error.localizedDescription)。正文已保存，可稍后手动建档。"))
            return false
        }
        guard !Task.isCancelled else { finish(.stopped); return false }

        guard let result = LLMJSONParser.decode(LLMJSONParser.SummaryResult.self, fromJSONObjectIn: raw) else {
            // 摘要解析失败不阻断流水线：正文已落，缺档案只影响下一章上下文质量
            finish(.failed("《\(chapter.title)》摘要解析失败，已停止。正文已保存，可手动建档后继续。"))
            return false
        }
        let summary: ChapterSummary
        if let existing = chapter.summary {
            summary = existing
        } else {
            summary = ChapterSummary(summaryText: result.summary)
            summary.chapter = chapter
            chapter.summary = summary
        }
        summary.summaryText = result.summary
        summary.keyFacts = result.key_facts ?? []
        applyForeshadowExtractions(from: result, chapter: chapter, novel: novel)
        return true
    }

    /// 伏笔登记（与 ChapterEditorView 同规则：新伏笔静默追加、回收标记 suggestedResolved）
    private func applyForeshadowExtractions(from result: LLMJSONParser.SummaryResult,
                                            chapter: Chapter, novel: Novel) {
        guard let volume = chapter.volume else { return }
        let volumeIndex = novel.sortedVolumes.firstIndex(where: { $0.id == volume.id }).map { $0 + 1 }
        for extraction in (result.new_foreshadowings ?? []).prefix(10) {
            let title = (extraction.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            novel.foreshadowings.append(Foreshadowing(
                title: String(title.prefix(PromptLimits.foreshadowTextFieldCap)),
                detail: (extraction.detail ?? "").isEmpty ? nil : String(extraction.detail!.prefix(PromptLimits.foreshadowTextFieldCap)),
                plantedVolumeIndex: volumeIndex,
                plantedChapterOrder: chapter.sortOrder,
                plannedResolve: (extraction.planned_resolve ?? "").isEmpty ? nil : String(extraction.planned_resolve!.prefix(PromptLimits.foreshadowTextFieldCap))
            ))
        }
        var matched = 0
        for candidate in (result.resolved_foreshadowing_titles ?? []) where matched < 5 {
            let target = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { continue }
            if let index = novel.foreshadowings.firstIndex(where: { $0.status == .open && ($0.title.contains(target) || target.contains($0.title)) }) {
                novel.foreshadowings[index].suggestedResolved = true
                matched += 1
            }
        }
    }

    private static func client(for provider: ProviderConfig) -> OpenAICompatibleClient {
        let key = KeychainHelper.load(account: provider.apiKeyID) ?? ""
        return OpenAICompatibleClient(baseUrl: URL(string: provider.baseUrl)!, apiKey: key, model: provider.modelName)
    }
}
#endif

#if os(iOS) || os(macOS)
import Foundation
import ZhiMingCore

/// 同人注入统一入口：把「档案 + 目标串」算成可注入的窗口文本。
/// 立项（澄清/结构/蓝图/卷纲/细纲）与写作（续写/撰写）都从这里取素材。
enum SourceScanInjection {

    /// 给出档案，渲染全文梗概（澄清 4000 / 结构蓝图 8000 由调用方传 maxChars）
    static func sourceContext(profile: SourceNovelProfile, maxChars: Int) -> String? {
        guard profile.scanState.isComplete else { return nil }
        if profile.continuationFromChapter != nil {
            // 续写档案：人物快照/伏笔/剧情弧 + 近期原文滚动注入（蓝图/细纲/写作共用此路径）
            let recent = ContinuationStore.loadTail(profileID: profile.id, maxChars: 1200)
            let body = ContinuationContext.rendered(profile: profile, recentText: recent, maxChars: maxChars)
            let title = profile.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let header = title.isEmpty ? "" : "原作：《\(title)》"
            return [header, body].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        let window = SourceTimeWindow.window(phase: nil, profile: profile)
        let title = profile.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = title.isEmpty ? "" : "原作：《\(title)》"
        let body = window.rendered(maxChars: maxChars)
        return [header, body].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// 按目标串（卷名/章标题）定位最近的原作阶段，返回该时间窗文本（未完成分析返回 nil）
    static func sourceWindow(profile: SourceNovelProfile, target: String?, maxChars: Int) -> String? {
        guard profile.scanState.isComplete else { return nil }
        if profile.continuationFromChapter != nil {
            // 续写档案不走阶段开窗：档案本身即「截至 X 章」的时间窗
            return sourceContext(profile: profile, maxChars: maxChars)
        }
        let phase = target.flatMap { nearestPhase(for: $0, in: profile) }
        let window = SourceTimeWindow.window(phase: phase, profile: profile)
        let body = window.rendered(maxChars: maxChars)
        guard !body.isEmpty else { return nil }
        return body
    }

    /// 目标串与档案阶段的启发式匹配：取字符重叠最多的阶段；无命中返回 nil
    static func nearestPhase(for target: String, in profile: SourceNovelProfile) -> String? {
        let phases = Array(Set(profile.timeline.compactMap { $0.phase?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
        guard !phases.isEmpty else { return nil }
        let targetSet = Set(target)
        var bestPhase: String?
        var bestScore = 0
        for phase in phases {
            // 字符重叠（独有字符交集）作为相似度；短阶段名也参与，避免长阶段名恒赢
            let score = Set(phase).intersection(targetSet).count
            if score > bestScore {
                bestScore = score
                bestPhase = phase
            }
        }
        return bestScore > 0 ? bestPhase : nil
    }

    /// 从书库解析 book 的档案并渲染窗口文本（写作路径：ChapterEditorView/AutoWrite 用）
    static func sourceWindow(novel: Novel, profiles: [SourceNovelProfile],
                             chapter: Chapter? = nil, target: String? = nil, maxChars: Int = 3000) -> String? {
        guard let id = novel.sourceProfileID,
              let profile = profiles.first(where: { $0.id == id }) else { return nil }
        // 优先目标串；无目标时按章节所在卷名定位阶段
        let effectiveTarget = target ?? chapter?.volume?.name
        return sourceWindow(profile: profile, target: effectiveTarget, maxChars: maxChars)
    }

    /// 澄清/结构/蓝图的全书梗概（带书名头）
    static func sourceContext(novel: Novel, profiles: [SourceNovelProfile], maxChars: Int) -> String? {
        guard let id = novel.sourceProfileID,
              let profile = profiles.first(where: { $0.id == id }) else { return nil }
        return sourceContext(profile: profile, maxChars: maxChars)
    }
}
#endif
import Foundation

/// 小说统计结果
public struct NovelStatistics {
    public let totalWordCount: Int            // 全书总字数
    public let todayWordCount: Int            // 今日新增字数
    public let completedChapters: Int         // 完成章数（≥1000 字）
    public let draftChapters: Int             // 草稿章数（>0 字）
    public let emptyChapters: Int             // 空章节数（0 字）
    public let averageChapterWords: Int       // 平均每章字数
    public let chapterWordCounts: [(title: String, wordCount: Int)]  // 各章字数（按卷章序）

    public static let empty = NovelStatistics(
        totalWordCount: 0, todayWordCount: 0, completedChapters: 0,
        draftChapters: 0, emptyChapters: 0, averageChapterWords: 0,
        chapterWordCounts: []
    )
}

/// 小说统计服务
public enum StatisticsService {

    /// 判定「完成」的字数阈值
    public static let completedThreshold = 1000

    public static func calculate(for novel: Novel) -> NovelStatistics {
        var total = 0
        var completed = 0
        var draft = 0
        var empty = 0
        var counts: [(title: String, wordCount: Int)] = []

        for volume in novel.sortedVolumes {
            for chapter in volume.chapters.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let words = chapter.content.count
                total += words
                if words == 0 {
                    empty += 1
                } else if words >= completedThreshold {
                    completed += 1
                } else {
                    draft += 1
                }
                counts.append((title: chapter.title, wordCount: words))
            }
        }

        let average = counts.isEmpty ? 0 : total / counts.count
        return NovelStatistics(
            totalWordCount: total,
            todayWordCount: todayWordCount(for: novel, currentTotal: total),
            completedChapters: completed,
            draftChapters: draft,
            emptyChapters: empty,
            averageChapterWords: average,
            chapterWordCounts: counts
        )
    }

    /// 今日新增 = 当日且基线存在时的差值，否则 0
    private static func todayWordCount(for novel: Novel, currentTotal: Int) -> Int {
        guard let date = novel.lastStatsDate,
              Calendar.current.isDateInToday(date) else { return 0 }
        return max(0, currentTotal - novel.lastTotalWordCount)
    }

    /// 若非今日则更新每日基线，返回是否已更新
    public static func updateDailyBaseline(for novel: Novel) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if let date = novel.lastStatsDate,
           Calendar.current.isDate(date, inSameDayAs: Date()) {
            return false
        }
        novel.lastStatsDate = today
        novel.lastTotalWordCount = totalWordCount(of: novel)
        return true
    }

    private static func totalWordCount(of novel: Novel) -> Int {
        novel.sortedVolumes.reduce(0) { sum, volume in
            sum + volume.chapters.reduce(0) { $0 + $1.content.count }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI
import ZhiMingCore

/// 作品统计页：总字数 / 今日新增 / 章节进度 / 各章字数分布
struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var novel: Novel
    @State private var stats = NovelStatistics.empty

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing[3]) {
                if novel.volumes.isEmpty {
                    EmptyStateView(
                        title: "暂无数据",
                        systemImage: "chart.bar.xaxis",
                        description: "先创建卷与章节，开始写作后这里会显示统计。"
                    )
                    .padding(.top, 80)
                } else {
                    metricGrid
                    chapterProgressCard
                    chapterDistributionCard
                }
            }
            .padding(AppTheme.spacing[3])
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        // 跨天更新今日字数基线，并持久化基线
        if StatisticsService.updateDailyBaseline(for: novel) {
            store.save()
        }
        stats = StatisticsService.calculate(for: novel)
    }
}

// MARK: - 私有卡片组件

extension StatisticsView {
    /// 四宫格核心指标
    private var metricGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 2),
            spacing: AppTheme.spacing[3]
        ) {
            StatCard(icon: "character.book.closed.fill", tint: .blue, title: "总字数", value: "\(stats.totalWordCount)")
            StatCard(
                icon: "pencil.line", tint: .green, title: "今日新增",
                value: stats.todayWordCount > 0 ? "+\(stats.todayWordCount)" : "0",
                footnote: stats.todayWordCount == 0 ? "今日尚未写作" : nil
            )
            StatCard(icon: "text.alignleft", tint: .indigo, title: "平均章节字数", value: "\(stats.averageChapterWords)")
            StatCard(
                icon: "book.pages.fill", tint: .orange, title: "章节总数",
                value: "\(stats.completedChapters + stats.draftChapters + stats.emptyChapters)"
            )
        }
    }

    /// 章节进度：三类状态占比条
    private var chapterProgressCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
            Text("章节进度").font(.headline)
            HStack(spacing: AppTheme.spacing[3]) {
                ProgressSegment("已完成", stats.completedChapters, fraction(of: stats.completedChapters), .green)
                ProgressSegment("草稿中", stats.draftChapters, fraction(of: stats.draftChapters), .orange)
                ProgressSegment("未开始", stats.emptyChapters, fraction(of: stats.emptyChapters), .gray)
            }
        }
        .padding(AppTheme.spacing[3])
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
        )
    }

    /// 各章字数分布条形图
    private var chapterDistributionCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[2]) {
            Text("各章字数分布").font(.headline)
            if stats.chapterWordCounts.isEmpty {
                Text("暂无章节数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let maxCount = max(1, stats.chapterWordCounts.map(\.wordCount).max() ?? 1)
                ForEach(Array(stats.chapterWordCounts.enumerated()), id: \.offset) { index, item in
                    ChapterBarRow(title: item.title, wordCount: item.wordCount, maxCount: maxCount)
                    if index < stats.chapterWordCounts.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(AppTheme.spacing[3])
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
        )
    }

    /// 占比：总数>0 返回该量占比，否则 0
    private func fraction(of count: Int) -> Double {
        let total = stats.completedChapters + stats.draftChapters + stats.emptyChapters
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
}

/// 核心指标卡片
private struct StatCard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            HStack(spacing: AppTheme.spacing[1]) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacing[2])
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

/// 章节进度条片段
private struct ProgressSegment: View {
    let title: String
    let count: Int
    let fraction: Double
    let tint: Color

    init(_ title: String, _ count: Int, _ fraction: Double, _ tint: Color) {
        self.title = title
        self.count = count
        self.fraction = fraction
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[0]) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint.opacity(0.2))
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint.opacity(0.85))
                    .frame(width: 44 * fraction)
            }
            .frame(height: 6)
            Text("\(title) \(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 单章字数条形行
private struct ChapterBarRow: View {
    let title: String
    let wordCount: Int
    let maxCount: Int

    var body: some View {
        HStack(spacing: AppTheme.spacing[2]) {
            Text(title)
                .font(.footnote)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(4, geo.size.width * CGFloat(wordCount) / CGFloat(maxCount)))
                }
            }
            .frame(height: 10)
            Text("\(wordCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
#endif

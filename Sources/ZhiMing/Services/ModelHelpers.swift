import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// 模型层的通用辅助（排序、全局章序等）
extension Novel {
    var sortedVolumes: [Volume] {
        volumes.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 全书章节按卷序→章序展开
    var allChaptersInOrder: [Chapter] {
        sortedVolumes.flatMap { $0.sortedChapters }
    }

    /// 章节在全书中的序号（从 1 开始）
    func globalIndex(of chapter: Chapter) -> Int {
        allChaptersInOrder.firstIndex(where: { $0.id == chapter.id }).map { $0 + 1 } ?? 0
    }

    /// 按（卷序, 章序）定位全局章序（1-based）；找不到返回 0
    func globalIndex(volumeIndex: Int, chapterOrder: Int) -> Int {
        guard let volume = sortedVolumes[safe: volumeIndex - 1],
              let chapter = volume.sortedChapters.first(where: { $0.sortOrder == chapterOrder }) else {
            return 0
        }
        return globalIndex(of: chapter)
    }
}

extension Volume {
    var sortedChapters: [Chapter] {
        chapters.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 归一化章序为 1...n（增删/移动后调用）
    func normalizeChapterOrder() {
        for (index, chapter) in sortedChapters.enumerated() {
            chapter.sortOrder = index + 1
        }
    }
}

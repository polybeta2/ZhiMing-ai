import Foundation

/// 版本快照：回退前先把当前内容存为新快照（triggerType = "restore"），历史永不丢失
enum SnapshotService {
    static func snapshot(_ chapter: Chapter, trigger: String) {
        let nextVersion = (chapter.snapshots.map(\.versionNumber).max() ?? 0) + 1
        let snap = ChapterSnapshot(versionNumber: nextVersion, content: chapter.content, triggerType: trigger)
        snap.chapter = chapter
        chapter.snapshots.append(snap)
    }

    static func restore(_ chapter: Chapter, to snapshot: ChapterSnapshot) {
        self.snapshot(chapter, trigger: "restore")
        chapter.content = snapshot.content
        chapter.wordCount = snapshot.content.count
        chapter.updatedAt = .now
    }
}

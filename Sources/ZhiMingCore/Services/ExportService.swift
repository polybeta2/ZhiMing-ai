import Foundation

/// 导出格式
public enum ExportFormat: Hashable {
    case txt
    case markdown
}

/// 导出范围
public enum ExportScope: Hashable {
    case fullNovel       // 全书
    case singleVolume(UUID)  // 单卷
    case outlineOnly     // 仅大纲
}

/// 小说导出服务（TXT / Markdown）
public enum ExportService {

    // MARK: - 导出入口

    public static func export(novel: Novel, scope: ExportScope, format: ExportFormat) -> String {
        switch scope {
        case .fullNovel:
            return renderFullNovel(novel, format: format)
        case .singleVolume(let volumeID):
            guard let volume = novel.sortedVolumes.first(where: { $0.id == volumeID }) else { return "" }
            return renderVolume(volume, novel: novel, format: format)
        case .outlineOnly:
            return renderOutline(novel, format: format)
        }
    }

    public static func fileName(novel: Novel, scope: ExportScope, format: ExportFormat) -> String {
        let ext = format == .txt ? "txt" : "md"
        let base = "《\(novel.title)》"
        switch scope {
        case .fullNovel:
            return "\(base)-全书.\(ext)"
        case .singleVolume(let volumeID):
            let name = novel.sortedVolumes.first(where: { $0.id == volumeID })?.name ?? "卷"
            return "\(base)-\(name).\(ext)"
        case .outlineOnly:
            return "\(base)-大纲.\(ext)"
        }
    }

    /// 原子写入临时目录（UTF-8），失败返回 nil
    public static func writeTemporaryFile(content: String, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - 正文渲染

    private static func renderFullNovel(_ novel: Novel, format: ExportFormat) -> String {
        var parts = [header(novel, format: format)]
        var globalIndex = 1
        for volume in novel.sortedVolumes {
            parts.append(volumeTitleText(volume, format: format))
            for chapter in sortedChapters(of: volume) {
                parts.append(chapterText(chapter, number: globalIndex, format: format))
                globalIndex += 1
            }
        }
        return parts.joined(separator: separator())
    }

    private static func renderVolume(_ volume: Volume, novel: Novel, format: ExportFormat) -> String {
        var parts = [header(novel, format: format), volumeTitleText(volume, format: format)]
        let chapters = sortedChapters(of: volume)
        for (index, chapter) in chapters.enumerated() {
            parts.append(chapterText(chapter, number: index + 1, format: format)) // 卷内编号从 1 开始
        }
        return parts.joined(separator: separator())
    }

    // MARK: - 片段

    private static func header(_ novel: Novel, format: ExportFormat) -> String {
        var lines: [String] = []
        switch format {
        case .txt:
            lines.append("《\(novel.title)》")
        case .markdown:
            lines.append("# 《\(novel.title)》")
        }
        let synopsis = novel.synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        if !synopsis.isEmpty {
            switch format {
            case .txt:
                lines.append("\n[梗概：\n\(synopsis)\n\n]")
            case .markdown:
                lines.append("\n**梗概**：\(synopsis)")
            }
        }
        return lines.joined(separator: "\n\n")
    }

    private static func volumeTitleText(_ volume: Volume, format: ExportFormat) -> String {
        switch format {
        case .txt:
            return "第\(volume.sortOrder)卷：\(volume.name)"
        case .markdown:
            return "## 第\(volume.sortOrder)卷：\(volume.name)"
        }
    }

    private static func chapterText(_ chapter: Chapter, number: Int, format: ExportFormat) -> String {
        let heading: String
        if chapter.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            heading = "第\(number)章"
        } else {
            heading = format == .txt
                ? "第\(number)章 \(chapter.title)"
                : "### 第\(number)章 \(chapter.title)"
        }
        let body = chapter.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = body.isEmpty ? "（本章暂无正文）" : body
        return "\(heading)\n\n\(text)"
    }

    // MARK: - 大纲渲染

    private static func renderOutline(_ novel: Novel, format: ExportFormat) -> String {
        let md = format == .markdown
        var parts: [String] = []
        parts.append(md ? "# 《\(novel.title)》大纲" : "《\(novel.title)》大纲")

        if !novel.synopsis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(md ? "**梗概**：\(novel.synopsis)" : "梗概：\(novel.synopsis)")
        }
        if let genre = novel.genre, !genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(md ? "**类型**：\(genre)" : "类型：\(genre)")
        }
        if let perspective = novel.perspective, !perspective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(md ? "**视角**：\(perspective)" : "视角：\(perspective)")
        }

        for volume in novel.sortedVolumes {
            parts.append(md ? "## 第\(volume.sortOrder)卷：\(volume.name)" : "第\(volume.sortOrder)卷：\(volume.name)")
            let outline = volume.outline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !outline.isEmpty {
                parts.append(md ? "- **卷纲**：\(outline)" : "卷纲：\(outline)")
            }
            if let arc = volume.emotionArc, !arc.isEmpty {
                parts.append(md ? "- **情绪走向**：\(arc.joined(separator: " → "))" : "情绪走向：\(arc.joined(separator: " → "))")
            }
            if let ladder = volume.conflictLadder {
                for rung in ladder.sorted(by: { $0.level < $1.level }) {
                    if let tp = rung.turningPoint, !tp.isEmpty {
                        parts.append(md ? "- **L\(rung.level) \(rung.obstacle)（转折：\(tp)）**" : "  L\(rung.level) \(rung.obstacle)（转折：\(tp)）")
                    } else {
                        parts.append(md ? "- **L\(rung.level)** \(rung.obstacle)" : "  L\(rung.level) \(rung.obstacle)")
                    }
                }
            }
            if let gap = volume.infoGap, !gap.isEmpty {
                parts.append(md ? "- **信息差**：起点「\(gap.start)」→ 终点「\(gap.end)」" : "信息差：起点「\(gap.start)」→ 终点「\(gap.end)」")
            }
            for chapter in sortedChapters(of: volume) {
                parts.append(md ? "### 第\(chapter.sortOrder)章：\(chapter.title)" : "第\(chapter.sortOrder)章：\(chapter.title)")
                let detail = chapter.detailedOutline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !detail.isEmpty {
                    parts.append(md ? "- **细纲**：\(detail)" : "  细纲：\(detail)")
                }
                if let cards = chapter.sceneCards {
                    for (index, card) in cards.enumerated() where !card.isEmpty {
                        parts.append(md
                            ? "- **场景卡\(index + 1)**：目标「\(card.goal)」｜阻力「\(card.obstacle)」｜钩子「\(card.hook)」"
                            : "  场景卡\(index + 1)：目标「\(card.goal)」｜阻力「\(card.obstacle)」｜钩子「\(card.hook)」")
                    }
                }
            }
        }
        return parts.joined(separator: separator())
    }

    // MARK: - 工具

    private static func separator() -> String {
        "\n\n---\n\n"
    }

    private static func sortedChapters(of volume: Volume) -> [Chapter] {
        volume.chapters.sorted { $0.sortOrder < $1.sortOrder }
    }
}

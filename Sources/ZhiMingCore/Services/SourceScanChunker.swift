import Foundation

/// 全书切章 + 分块。章划分复用 StyleChapterSampler.split（含假章裁决）；
/// 分块：fast=每章 头 headChars + 尾 tailChars 两窗（窗口超章长时整章为一块）；
/// full=每章按整块正文推进（块字符 chunkChars）。无章节标记时回退整文本三窗采样。
public enum SourceScanChunker {

    public struct Chunk: Equatable {
        public let chapterIndex: Int   // 原始章序（0-based，配合 StyleChapterSampler 结果）
        public let chunkIndex: Int     // 全书块序（0-based，断点续传键用）
        public let text: String
    }

    public static func chunks(from text: String, mode: ScanMode,
                              headChars: Int = 2500, tailChars: Int = 1500,
                              chunkChars: Int = 10000, mergeTailUnder: Int = 2000) -> [Chunk] {
        let chapters = StyleChapterSampler.split(text)
        if chapters.isEmpty {
            return fallbackWindows(from: text, headChars: headChars, tailChars: tailChars)
        }
        var result: [Chunk] = []
        for (ci, chapter) in chapters.enumerated() {
            let body = chapter.body
            if body.isEmpty { continue }
            switch mode {
            case .fast:
                let head = String(body.prefix(headChars))
                let tail = String(body.suffix(tailChars))
                // 窗口重叠或覆盖全章 → 单块
                if head.count + tail.count >= body.count || body.count <= max(headChars, tailChars) {
                    result.append(Chunk(chapterIndex: ci, chunkIndex: result.count, text: body))
                } else {
                    result.append(Chunk(chapterIndex: ci, chunkIndex: result.count, text: head))
                    result.append(Chunk(chapterIndex: ci, chunkIndex: result.count, text: tail))
                }
            case .full:
                var start = body.startIndex
                while start < body.endIndex {
                    let remaining = body.distance(from: start, to: body.endIndex)
                    let take = min(chunkChars, remaining)
                    let end = body.index(start, offsetBy: take)
                    let block = String(body[start..<end])
                    // 尾块太小并入前一（保持 chunkIndex 连续不真并，reducer 同批处理）
                    if block.count < mergeTailUnder, let last = result.last, last.chapterIndex == ci {
                        result[result.count - 1] = Chunk(
                            chapterIndex: last.chapterIndex, chunkIndex: last.chunkIndex,
                            text: last.text + block)
                    } else {
                        result.append(Chunk(chapterIndex: ci, chunkIndex: result.count, text: block))
                    }
                    start = end
                }
            }
        }
        return result
    }

    /// 无章回退：整文本按首/中/尾三窗折叠（蒸馏同款兜底），不切章
    private static func fallbackWindows(from text: String, headChars: Int, tailChars: Int) -> [Chunk] {
        var result: [Chunk] = []
        let head = String(text.prefix(headChars))
        let tail = String(text.suffix(tailChars))
        guard head.count + tail.count < text.count else {
            return [Chunk(chapterIndex: 0, chunkIndex: 0, text: text)]
        }
        let midStart = text.index(text.startIndex, offsetBy: headChars)
        let midEnd = text.index(text.endIndex, offsetBy: -tailChars)
        result.append(Chunk(chapterIndex: 0, chunkIndex: 0, text: head))
        if midStart < midEnd {
            result.append(Chunk(chapterIndex: 0, chunkIndex: result.count, text: String(text[midStart..<midEnd])))
        }
        result.append(Chunk(chapterIndex: 0, chunkIndex: result.count, text: tail))
        return result
    }
}

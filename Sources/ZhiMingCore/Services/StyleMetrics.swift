import Foundation

/// 本地文风计量：纯 Foundation 文本统计，零 LLM 成本、确定性输出。
/// 用途：① 蒸馏 S1 阶段为 LLM 提供客观锚点；② S4 阶段查重（蒸馏产物 vs 原文）。
/// 只统计、不评判——与 ProseChecker「只报告不修改」同纪律。
public enum StyleMetrics {

    public struct Sample: Equatable {
        public let text: String
        public let label: String
    }

    // MARK: 分段采样（首/中/尾，对齐 novel-style-skills 的采样纪律）

    /// 超过 maxChars 时取首/中/尾各约 1/3；不足时全文单段。
    public static func sampleSegments(in full: String, maxChars: Int) -> [Sample] {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > maxChars else { return [Sample(text: trimmed, label: "全文")] }
        let part = maxChars / 3
        let head = String(trimmed.prefix(part))
        let middleStart = trimmed.index(trimmed.startIndex, offsetBy: (trimmed.count - part) / 2)
        let middle = String(trimmed[middleStart..<trimmed.index(middleStart, offsetBy: part)])
        let tail = String(trimmed.suffix(part))
        return [Sample(text: head, label: "开头"), Sample(text: middle, label: "中段"), Sample(text: tail, label: "结尾")]
    }

    // MARK: 计量主入口

    public static func compute(_ text: String) -> StyleMetricsSnapshot {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let charCount = trimmed.count
        guard charCount > 0 else { return StyleMetricsSnapshot() }

        let separators: Set<Character> = ["。", "！", "？", "；", "!", "?", ";", "\n"]
        let sentences = trimmed
            .split(omittingEmptySubsequences: true, whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let lengths = sentences.map(\.count).sorted()

        var short = 0, long = 0
        for len in lengths {
            if len <= 10 { short += 1 }
            if len >= 25 { long += 1 }
        }
        let sentenceCount = lengths.count

        var alternation = 0
        if sentenceCount >= 2 {
            func category(_ len: Int) -> Int { len <= 10 ? 0 : (len >= 25 ? 2 : 1) }
            for i in 1..<sentenceCount where category(lengths[i]) != category(lengths[i - 1]) {
                alternation += 1
            }
        }

        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let quoted = lines.filter { $0.contains("“") || $0.contains("「") || $0.contains("『") || $0.contains("\"") }

        func per1k(_ occurrences: Int) -> Double {
            Double(occurrences) / Double(charCount) * 1000
        }

        return StyleMetricsSnapshot(
            sampleCharCount: charCount,
            sentenceCount: sentenceCount,
            medianSentenceLength: median(lengths),
            shortSentenceRatio: sentenceCount == 0 ? 0 : Double(short) / Double(sentenceCount),
            longSentenceRatio: sentenceCount == 0 ? 0 : Double(long) / Double(sentenceCount),
            alternationRate: sentenceCount < 2 ? 0 : Double(alternation) / Double(sentenceCount - 1),
            dialogueLineRatio: lines.isEmpty ? 0 : Double(quoted.count) / Double(lines.count),
            dashPer1k: per1k(components(of: "——", in: trimmed)),
            ellipsisPer1k: per1k(components(of: "……", in: trimmed)),
            exclamationPer1k: per1k(charOccurrences(of: "！", in: trimmed) + charOccurrences(of: "!", in: trimmed)),
            questionPer1k: per1k(charOccurrences(of: "？", in: trimmed) + charOccurrences(of: "?", in: trimmed))
        )
    }

    private static func median(_ sorted: [Int]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return Double(sorted[mid]) }
        return Double(sorted[mid - 1] + sorted[mid]) / 2
    }

    private static func components(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return text.components(separatedBy: needle).count - 1
    }

    private static func charOccurrences(of ch: Character, in text: String) -> Int {
        text.filter { $0 == ch }.count
    }

    // MARK: n-gram 查重（S4 护栏：蒸馏产物不得与原文有长片段重合）

    /// 原文 n-gram 索引：构建一次、多候选复用（大样本下逐候选重建是性能陷阱）。
    public struct NgramIndex {
        fileprivate let grams: Set<String>
        private let n: Int

        fileprivate init(grams: Set<String>, n: Int) {
            self.grams = grams
            self.n = n
        }

        /// 候选命中任意一个原文 n-gram 即视为违规
        public func hasViolation(_ candidate: String) -> Bool {
            !violations(in: [candidate]).isEmpty
        }

        /// 批量查重：按候选文本中的位置顺序返回最早违规窗口（确定性，去重）
        public func violations(in candidates: [String]) -> [String] {
            var hits: [String] = []
            for candidate in candidates {
                let chars = Array(StyleMetrics.normalized(candidate))
                guard chars.count >= n else { continue }
                var found: String?
                for i in 0...(chars.count - n) {
                    let window = String(chars[i..<(i + n)])
                    if grams.contains(window) {
                        found = window
                        break
                    }
                }
                if let hit = found, !hits.contains(hit) {
                    hits.append(hit)
                }
            }
            return hits
        }
    }

    /// 为原文构建查重索引（大文本构建成本高，务必复用）
    public static func ngramIndex(of original: String, n: Int = 8) -> NgramIndex {
        NgramIndex(grams: ngrams(of: original, n: n), n: n)
    }

    /// 单候选便捷方法（一次性检查用；多候选请用 ngramIndex 复用）
    public static func hasViolation(_ candidate: String, against original: String, n: Int = 8) -> Bool {
        ngramIndex(of: original, n: n).hasViolation(candidate)
    }

    /// 批量便捷方法（一次性检查用；多候选请用 ngramIndex 复用）
    public static func ngramViolations(in candidates: [String], against original: String, n: Int = 8) -> [String] {
        ngramIndex(of: original, n: n).violations(in: candidates)
    }

    private static func ngrams(of text: String, n: Int) -> Set<String> {
        let chars = Array(normalized(text))
        guard chars.count >= n else { return [] }
        var result = Set<String>()
        for i in 0...(chars.count - n) {
            result.insert(String(chars[i..<(i + n)]))
        }
        return result
    }

    /// 归一化：去标点/空白/大小写（标点差异不算原创，与上游方法论一致）
    private static func normalized(_ text: String) -> String {
        let dropped: Set<Character> = ["，", "。", "！", "？", "；", "：", "、", "“", "”", "‘", "’",
                                       "「", "」", "『", "』", "（", "）", "《", "》", "【", "】",
                                       "…", "—", "\n", "\r", "\t", " ", ",", ".", ";", ":", "!", "?", "'", "\"", "(", ")", "<", ">"]
        return String(text.lowercased().filter { !dropped.contains($0) })
    }
}

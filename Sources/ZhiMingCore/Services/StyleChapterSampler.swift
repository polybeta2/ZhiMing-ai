import Foundation

/// 长篇章节划分与自适应抽样：
/// 整本网文按「第X章 / 001 / Chapter 12 / 第两百三十四章」等标题行切成章，
/// 抽样策略 = 前 2 章 + 后 2 章 + 中段随机 2 章；AI 判定样本不足时每轮补随机 2 章，至多 10 章。
///
/// 划分必须做裁决：正文里孤立的数字行（页码/年份等）会形成假章节，特征是
/// 序号「尖刺后回落」（如 028, 029, 178, 191, 030 中的 178/191）——此类标记整段舍弃，
/// 其正文并回前一个存活章。单调跳号（如 30 → 35，缺卷）不算尖刺，保留。
public enum StyleChapterSampler {

    public struct SampleChapter: Equatable {
        public let marker: String      // 章节标题行（原样，去首尾空白）
        public let number: Int?        // 解析出的章号（「序章」等无数字标题为 nil）
        public let symbol: Character?  // 标记后缀类别：章/节/回/卷/集；纯数字行与 Chapter 12 为 nil
        public let body: String        // 标题行之后的正文
    }

    /// 卷/集标记不参与尖刺裁决（真实网文常「第N集」混插连续章号，参与会误删后续全部章节）
    private static let adjudicatableSymbols: Set<Character> = ["章", "节", "回"]

    /// 抽样规模：首轮 6 章，每轮补 2 章，至多 10 章
    public static let initialCount = 6
    public static let expandStep = 2
    public static let maxChapters = 10

    // MARK: - 划分（切章 + 裁决 + 回并）

    /// 无章节标记时返回空数组（调用方回退到首/中/尾三窗采样）
    public static func split(_ text: String) -> [SampleChapter] {
        let lines = text.components(separatedBy: .newlines)

        // 第一遍：按标记行切原始章
        var raw: [(marker: String, number: Int?, symbol: Character?, body: String)] = []
        var pending: [String] = []
        var preamble = ""
        var lastMarker: (marker: String, number: Int?, symbol: Character?)?
        for line in lines {
            if let number = markerNumber(in: line) {
                let symbol = markerSymbol(in: line)
                let body = pending.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let last = lastMarker {
                    raw.append((last.marker, last.number, last.symbol, body))
                } else if !body.isEmpty {
                    preamble = body   // 首个标记前通常是版权页/书名，不入样但保留给首章
                }
                pending = []
                lastMarker = (line.trimmingCharacters(in: .whitespaces), number, symbol)
            } else {
                pending.append(line)
            }
        }
        if let last = lastMarker {
            raw.append((last.marker, last.number, last.symbol,
                        pending.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        guard !raw.isEmpty else { return [] }

        // 第二遍：序号裁决（回落型尖刺 = 假标记；卷/集标记不参与）
        let survivors = adjudicate(raw)

        // 第三遍：存活章组装；被裁标记（含其正文）按文档序并回上一个存活章
        var result: [SampleChapter] = []
        var pendingDrop: [String] = []
        for (i, chapter) in raw.enumerated() {
            if survivors.contains(i) {
                var body = chapter.body
                if result.isEmpty, !preamble.isEmpty {
                    body = (preamble + "\n" + body).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !pendingDrop.isEmpty {
                    body = (pendingDrop.joined(separator: "\n") + "\n" + body)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingDrop = []
                }
                result.append(SampleChapter(marker: chapter.marker, number: chapter.number,
                                            symbol: chapter.symbol, body: body))
            } else {
                pendingDrop.append(chapter.marker + "\n" + chapter.body)
            }
        }
        if !pendingDrop.isEmpty, !result.isEmpty {
            let last = result.removeLast()
            result.append(SampleChapter(
                marker: last.marker, number: last.number, symbol: last.symbol,
                body: (last.body + "\n" + pendingDrop.joined(separator: "\n"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return result
    }

    /// 序号裁决：返回存活的 raw 下标集合。
    /// 规则（按文档序）：连续重复章号舍弃后者；序号尖刺（> 前值 + 容差）且此后回落到
    /// 前值邻域 → 判为正文混入的数字（非章节）舍弃；单调跳号不回落则保留。
    /// 参与裁决的只有「章/节/回」与纯数字/Chapter 标记；卷/集级标记永远保留。
    static func adjudicate(_ raw: [(marker: String, number: Int?, symbol: Character?, body: String)]) -> Set<Int> {
        let numbered = raw.enumerated().compactMap { offset, chapter -> (offset: Int, number: Int)? in
            guard let number = chapter.number else { return nil }
            if let symbol = chapter.symbol, !adjudicatableSymbols.contains(symbol) {
                return nil   // 卷/集：保留但不参与裁决
            }
            return (offset, number)
        }
        guard numbered.count >= 3 else { return Set(raw.indices) }   // 序号太少不做裁决

        var forwardGaps: [Int] = []
        for i in 1..<numbered.count {
            let gap = numbered[i].number - numbered[i - 1].number
            if gap > 0 { forwardGaps.append(gap) }
        }
        guard let minGap = forwardGaps.min() else { return Set(raw.indices) }
        let tolerance = max(3, 5 * minGap)

        var keep = Set(raw.indices)
        var lastKept: Int?
        for (pos, item) in numbered.enumerated() {
            if let last = lastKept {
                if item.number == last {
                    keep.remove(item.offset)             // 连续重复标题
                    continue
                }
                if item.number > last + tolerance {
                    let returnsLater = numbered[(pos + 1)...].contains { abs($0.number - last) <= tolerance }
                    if returnsLater {
                        keep.remove(item.offset)         // 尖刺后回落：假标记
                        continue
                    }
                }
            }
            lastKept = item.number
        }
        return keep
    }

    // MARK: - 抽样

    /// 首轮：前 2 + 后 2 + 中段随机 2（返回按文档序排序的下标）；总数不足 6 章时全取
    public static func selectInitial(total: Int, pickRandom: (Range<Int>) -> Int) -> [Int] {
        guard total > 0 else { return [] }
        guard total > initialCount else { return Array(0..<total) }
        var picked: Set<Int> = [0, 1, total - 2, total - 1]
        var pool = Array(2..<(total - 2))
        // 大书优先在中间四分之一区间抽（对齐「靠向中间」语义）
        if total >= 12 {
            let middle = pool.filter { $0 >= total / 4 && $0 < total * 3 / 4 }
            if middle.count >= 2 { pool = middle }
        }
        for _ in 0..<2 where !pool.isEmpty {
            let idx = pickRandom(0..<pool.count)
            picked.insert(pool.remove(at: idx))
        }
        return picked.sorted()
    }

    /// 补样：从未选中章节随机加 expandStep 章，总量不超过 maxChapters
    public static func expand(_ selected: [Int], total: Int, pickRandom: (Range<Int>) -> Int) -> [Int] {
        var result = Set(selected)
        var pool = Array(0..<total).filter { !result.contains($0) }
        for _ in 0..<expandStep {
            guard !pool.isEmpty, result.count < maxChapters else { break }
            let idx = pickRandom(0..<pool.count)
            result.insert(pool.remove(at: idx))
        }
        return result.sorted()
    }

    // MARK: - 标记识别

    /// 判断一行是否章节标题，并解析章号。标题行必须短（≤40 字符），
    /// 且「第X章」必须顶格（前置空白允许），防止叙述文字里的「第3章」误切。
    static func markerNumber(in line: String) -> Int? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        // 全角数字/字母归一半角（０１２ → 012），失败则用原行
        if let halfwidth = trimmed.applyingTransform(.fullwidthToHalfwidth, reverse: false) {
            trimmed = halfwidth.trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return nil }

        // 纯数字行：001 / 28 / 191
        if trimmed.count <= 4, let n = Int(trimmed), n >= 1 { return n }

        // 第X章/节/回/卷/集（数字部分可含中文数字）
        if trimmed.hasPrefix("第") {
            var idx = trimmed.index(after: trimmed.startIndex)
            while idx < trimmed.endIndex, isNumeralChar(trimmed[idx]) {
                idx = trimmed.index(after: idx)
            }
            guard idx > trimmed.index(after: trimmed.startIndex) else { return nil }
            let rest = trimmed[idx...]
            if rest.hasPrefix("章") || rest.hasPrefix("节") || rest.hasPrefix("回")
                || rest.hasPrefix("卷") || rest.hasPrefix("集") {
                return parseChineseNumeral(String(trimmed[trimmed.index(after: trimmed.startIndex)..<idx]))
            }
            return nil
        }

        // Chapter 12
        if trimmed.lowercased().hasPrefix("chapter ") {
            let digits = trimmed.dropFirst(8).prefix { $0.isNumber }
            if let n = Int(digits), !digits.isEmpty { return n }
        }
        return nil
    }

    private static func isNumeralChar(_ ch: Character) -> Bool {
        ch.isNumber || "零〇一二三四五六七八九十百千万两".contains(ch)
    }

    /// 判断一行是否章节标题并返回后缀类别（章/节/回/卷/集）；非「第X…」形式（纯数字行/Chapter 12）为 nil
    static func markerSymbol(in line: String) -> Character? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if let halfwidth = trimmed.applyingTransform(.fullwidthToHalfwidth, reverse: false) {
            trimmed = halfwidth.trimmingCharacters(in: .whitespaces)
        }
        guard trimmed.hasPrefix("第") else { return nil }
        var idx = trimmed.index(after: trimmed.startIndex)
        while idx < trimmed.endIndex, isNumeralChar(trimmed[idx]) {
            idx = trimmed.index(after: idx)
        }
        guard idx < trimmed.endIndex else { return nil }
        let rest = trimmed[idx...]
        for symbol in ["章", "节", "回", "卷", "集"] where rest.hasPrefix(symbol) {
            return Character(symbol)
        }
        return nil
    }

    /// 中文数字解析（一百二十三 → 123，一万三千 → 13000）；半角数字直接解析
    static func parseChineseNumeral(_ raw: String) -> Int? {
        if let n = Int(raw) { return n }
        let digits: [Character: Int] = ["零": 0, "〇": 0, "一": 1, "二": 2, "三": 3, "四": 4,
                                        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "两": 2]
        let units: [Character: Int] = ["十": 10, "百": 100, "千": 1000]
        var total = 0, section = 0, digit = 0
        for ch in raw {
            if let d = digits[ch] {
                digit = d
            } else if let u = units[ch] {
                section += (digit == 0 ? 1 : digit) * u
                digit = 0
            } else if ch == "万" {
                total = (total + section + digit) * 10_000
                section = 0
                digit = 0
            } else {
                return nil
            }
        }
        let result = total + section + digit
        return result > 0 ? result : nil
    }
}

import Foundation

/// 批量复制分析协议（把最烧 token 的 Map 阶段外包给免费外部 AI App，如 DeepSeek App）：
/// 织命生成「系统指令 + 一批章节正文」的超长提示词 → 用户粘贴到外部 AI → 拿回逐章 JSON 微摘要。
/// 本类型负责：批次提示词装配 + 逐章 JSON 输出解析（宽容，容忍围栏/多余文字）。
public enum SourceBatchHelper {

    /// 每章微摘要 JSON 的典型长度（用于预估提示词体积）
    public static let perChapterEstimateChars = 600

    /// 单章在批次提示词里的格式
    static func chapterBlock(index: Int, title: String?, body: String) -> String {
        let marker = (title?.isEmpty == false) ? title! : "第\(index)章"
        return "【\(marker)】\n\(body)"
    }

    /// 生成一批的提示词（用户整段复制去外部 App）
    /// - Parameters:
    ///   - title: 书名（引导语用）
    ///   - chapters: 本轮章节，元素为 (1-based 章号, 本章标题, 正文)。章号保持全书顺序（断点续传键）
    public static func prompt(title: String?, chapters: [(index: Int, title: String?, body: String)]) -> String {
        guard !chapters.isEmpty else { return "" }
        let book = (title?.isEmpty == false) ? title! : "这部小说"
        let first = chapters.first!.index
        let last = chapters.last!.index
        var lines: [String] = []
        lines.append("【任务】你是小说内容分析师。下面是《\(book)》第 \(first)-\(last) 章的正文（共 \(chapters.count) 章）。")
        lines.append("请逐章输出「增量式微摘要」JSON：每章输出【一行】JSON 对象，章与章之间用换行分隔；除此之外不要输出任何内容（不要解释、不要代码块围栏、不要编号）。")
        lines.append("每章 JSON 格式（只记录本章「新增或变化」的信息：新角色、性格/能力表现、状态变化、发生的事件、新确立的设定、新埋或回收的伏笔；不要复述前文已知内容；本章无新增则对应字段给空数组）：")
        lines.append(#"{"chapter": <本章序号>, "characters": [{"name": "", "traits": "", "state_change": ""}], "events": [{"summary": "", "participants": []}], "worldbuilding": [{"name": "", "content": ""}], "foreshadowing": [{"summary": "本章新埋或回收的伏笔一句话", "planted": true}]}"#)
        lines.append("伏笔规则：本章新埋的记 planted=true（含线索）；本章回收（悬念解除）的记 planted=false；无则空数组。")
        lines.append("")
        for c in chapters {
            lines.append(chapterBlock(index: c.index, title: c.title, body: c.body))
        }
        return lines.joined(separator: "\n\n")
    }

    // MARK: - 输出解析

    /// 逐行/逐块解析外部 AI 输出为 章序号 → 微摘要。
    /// 宽容：可带 ``` 围栏与前后说明文字；每个 `{"chapter": N, ...}` 对象会被独立提取。
    public static func parseBatchOutput(_ raw: String) throws -> [Int: SourceMicroSummarizer.MicroSummary] {
        var result: [Int: SourceMicroSummarizer.MicroSummary] = [:]
        for json in extractJSONObjects(from: raw, matchingKey: "chapter") {
            guard let data = json.data(using: .utf8) else { continue }
            struct Entry: Codable {
                var chapter: Int?
                var characters: [SourceMicroSummarizer.MicroCharacter]?
                var events: [SourceMicroSummarizer.MicroEvent]?
                var worldbuilding: [SourceMicroSummarizer.MicroWorld]?
            }
            guard let entry = try? JSONDecoder().decode(Entry.self, from: data),
                  let idx = entry.chapter else { continue }
            var summary = SourceMicroSummarizer.MicroSummary()
            summary.characters = entry.characters ?? []
            summary.events = entry.events ?? []
            summary.worldbuilding = entry.worldbuilding ?? []
            result[idx - 1] = summary     // 章序号 1-based → chunk 序 0-based
        }
        guard !result.isEmpty else { throw SourceScanError.parseFailed }
        return result
    }

    /// 字符串感知地提取所有「以 key 开头的 {…} JSON 对象」（可多个，容忍换行/围栏）
    static func extractJSONObjects(from text: String, matchingKey: String) -> [String] {
        var objects: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard let brace = text[index...].firstIndex(of: "{") else { break }
            // 仅当对象以 {"key" 开头才纳入（避免捕获 explain 文本里的其它对象）
            let probeEnd = text.index(brace, offsetBy: matchingKey.count + 3, limitedBy: text.endIndex) ?? text.endIndex
            let probe = String(text[brace..<min(probeEnd, text.endIndex)]).replacingOccurrences(of: " ", with: "")
            guard probe.contains("{\"\(matchingKey)\"") else {
                index = text.index(after: brace)
                continue
            }
            if let end = closingBrace(from: brace, in: text) {
                objects.append(String(text[brace...end]))
                index = text.index(after: end)
            } else {
                index = text.index(after: brace)
            }
        }
        return objects
    }

    /// 从起点 { 配平到匹配的 }（字符串感知）
    static func closingBrace(from start: String.Index, in text: String) -> String.Index? {
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < text.endIndex {
            let ch = text[i]
            if escaped {
                escaped = false
            } else if inString && ch == "\\" {
                escaped = true
            } else if ch == "\"" {
                inString.toggle()
            } else if !inString {
                if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 { return i }
                }
            }
            i = text.index(after: i)
        }
        return nil
    }
}
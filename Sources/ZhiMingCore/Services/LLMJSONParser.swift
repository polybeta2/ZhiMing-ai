import Foundation

/// 从模型输出中提取 JSON（容忍 ```json 围栏、前后缀文字、数组/对象两种顶层结构）
public enum LLMJSONParser {
    /// 提取首个完整 JSON 值：`[` 开头取数组、`{` 开头取对象（取二者中更早出现者），
    /// 做字符串感知的括号配平，杜绝把 `[{...},{...}]` 截成 `{...},{...}` 的非法片段
    public static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let open = text[start]
        let close: Character = open == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < text.endIndex {
            let ch = text[index]
            if escaped {
                escaped = false
            } else if inString && ch == "\\" {
                escaped = true
            } else if ch == "\"" {
                inString.toggle()
            } else if !inString {
                if ch == open { depth += 1 }
                if ch == close {
                    depth -= 1
                    if depth == 0 { return String(text[start...index]) }
                }
            }
            index = text.index(after: index)
        }
        return nil   // 未闭合（多半被 maxTokens 截断），交给上层报错
    }

    public static func decode<T: Decodable>(_ type: T.Type, fromJSONObjectIn text: String) -> T? {
        guard let json = extractJSONObject(from: text),
              let data = json.data(using: .utf8),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return decodeLenient(type, in: text)
        }
        return value
    }

    /// 宽容重试：剥 ``` 围栏 + 清理尾逗号（` }]`/`,]` 常见于部分网关模型）后再解码
    private static func decodeLenient<T: Decodable>(_ type: T.Type, in text: String) -> T? {
        var candidate = text
        // 去掉 ```json / ``` 围栏行，只留围栏内内容
        if let fenceStart = candidate.range(of: "```"),
           let newline = candidate.range(of: "\n", range: fenceStart.upperBound..<candidate.endIndex) {
            let inner = String(candidate[newline.upperBound...])
            if let fenceEnd = inner.range(of: "```") {
                candidate = String(inner[..<fenceEnd.lowerBound])
            } else {
                candidate = inner
            }
        }
        guard let json = extractJSONObject(from: candidate) else { return nil }
        let cleaned = json
            .replacingOccurrences(of: #",\s*]"#, with: "]", options: .regularExpression)
            .replacingOccurrences(of: #",\s*}"#, with: "}", options: .regularExpression)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 摘要中提取出的单条新伏笔（字段对应 summarize 模板）
    public struct ForeshadowExtraction: Decodable {
        public let title: String?
        public let detail: String?
        public let planned_resolve: String?

        public init(title: String? = nil, detail: String? = nil, planned_resolve: String? = nil) {
            self.title = title
            self.detail = detail
            self.planned_resolve = planned_resolve
        }
    }

    /// 摘要解析结构（字段与 summarize 模板对应）
    public struct SummaryResult: Decodable {
        public let summary: String
        public let key_facts: [String]?
        public let new_foreshadowings: [ForeshadowExtraction]?
        public let resolved_foreshadowing_titles: [String]?

        public init(summary: String, key_facts: [String]? = nil, new_foreshadowings: [ForeshadowExtraction]? = nil, resolved_foreshadowing_titles: [String]? = nil) {
            self.summary = summary
            self.key_facts = key_facts
            self.new_foreshadowings = new_foreshadowings
            self.resolved_foreshadowing_titles = resolved_foreshadowing_titles
        }
    }
}

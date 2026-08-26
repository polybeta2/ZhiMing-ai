import Foundation

/// 从模型输出中提取 JSON（容忍 ```json 围栏与前后缀文字）
enum LLMJSONParser {
    static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return nil }
        return String(text[start...end])
    }

    static func decode<T: Decodable>(_ type: T.Type, fromJSONObjectIn text: String) -> T? {
        guard let json = extractJSONObject(from: text),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 摘要中提取出的单条新伏笔（字段对应 summarize 模板）
    struct ForeshadowExtraction: Decodable {
        let title: String?
        let detail: String?
        let planned_resolve: String?
    }

    /// 摘要解析结构（字段与 summarize 模板对应）
    struct SummaryResult: Decodable {
        let summary: String
        let key_facts: [String]?
        let new_foreshadowings: [ForeshadowExtraction]?
        let resolved_foreshadowing_titles: [String]?
    }
}

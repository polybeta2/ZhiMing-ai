import Foundation

/// Map 阶段：把单块正文压成增量式微摘要（只记新增/变化，输出 ≤ maxOutChars）。
public enum SourceMicroSummarizer {

    public struct MicroCharacter: Codable, Equatable {
        public var name: String
        public var traits: String?
        public var state_change: String?
        public init(name: String, traits: String? = nil, state_change: String? = nil) {
            self.name = name; self.traits = traits; self.state_change = state_change
        }
    }

    public struct MicroEvent: Codable, Equatable {
        public var summary: String
        public var participants: [String]
        public init(summary: String, participants: [String]) {
            self.summary = summary; self.participants = participants
        }
    }

    public struct MicroWorld: Codable, Equatable {
        public var name: String
        public var content: String
        public init(name: String, content: String) {
            self.name = name; self.content = content
        }
    }

    /// 章内伏笔：planted=true 本章新埋；false 本章回收
    public struct MicroForeshadow: Codable, Equatable {
        public var summary: String
        public var planted: Bool
        public init(summary: String, planted: Bool = true) {
            self.summary = summary; self.planted = planted
        }
    }

    public struct MicroSummary: Codable, Equatable {
        public var characters: [MicroCharacter] = []
        public var events: [MicroEvent] = []
        public var worldbuilding: [MicroWorld] = []
        public var foreshadowing: [MicroForeshadow] = []

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            characters = try c.decodeIfPresent([MicroCharacter].self, forKey: .characters) ?? []
            events = try c.decodeIfPresent([MicroEvent].self, forKey: .events) ?? []
            worldbuilding = try c.decodeIfPresent([MicroWorld].self, forKey: .worldbuilding) ?? []
            foreshadowing = try c.decodeIfPresent([MicroForeshadow].self, forKey: .foreshadowing) ?? []
        }

        enum CodingKeys: String, CodingKey { case characters, events, worldbuilding, foreshadowing }
    }

    /// 完整提示词（测试与预览用）：系统指令 + 章节标记 + 正文块
    public static func prompt(forChunk chunk: String, maxOutChars: Int = 350) -> String {
        systemPrompt(maxOutChars: maxOutChars) + "\n" + chunk
    }

    /// 请求装配（系统提示词 + 用户正文块）
    public static func messages(chunk: String, chapterMarker: String?) -> [LLMMessage] {
        let marker = (chapterMarker?.isEmpty == false) ? "（章节：\(chapterMarker!)）\n" : ""
        return [LLMMessage(role: .system, content: systemPrompt()),
                LLMMessage(role: .user, content: marker + chunk)]
    }

    private static func systemPrompt(maxOutChars: Int = 450) -> String {
        """
        你是小说内容分析师。用户给出一本小说的一段正文，请你只记录这一段「新增或变化」的信息，\
        只记本段新增/变化，不要复述前文已知内容。输出严格 JSON（不要输出其他内容，总长 ≤ \(maxOutChars) 字），字段：\
        {"characters": [{"name": "角色名", "traits": "本段展现的性格/能力特征", "state_change": "本段发生的状态变化（无则省略）"}],\
         "events": [{"summary": "本段发生的事件（一句话，含结果）", "participants": ["参与角色"]}],\
         "worldbuilding": [{"name": "设定/规则/地点/物品名", "content": "本段确立的内容"}],\
         "foreshadowing": [{"summary": "本章新埋或回收的伏笔（一句话，含线索）", "planted": true}]}\
        无新增则对应字段给空数组。伏笔规则：本章新埋的记 planted=true；本章回收（悬念解除）的记 planted=false。
        """
    }

    /// 宽容解析：剥 ``` 围栏后用 LLMJSONParser 提取 JSON → 解码；失败抛解析错误（调用方重试/降级）
    public static func parse(_ raw: String) throws -> MicroSummary {
        var candidate = raw
        if let fenceStart = candidate.range(of: "```"),
           let newline = candidate.range(of: "\n", range: fenceStart.upperBound..<candidate.endIndex) {
            let inner = candidate[newline.upperBound...]
            if let fenceEnd = inner.range(of: "```") {
                candidate = String(inner[..<fenceEnd.lowerBound])
            } else {
                candidate = String(inner)
            }
        }
        guard let json = LLMJSONParser.extractJSONObject(from: candidate),
              let data = json.data(using: .utf8) else {
            throw SourceScanError.parseFailed
        }
        return try JSONDecoder().decode(MicroSummary.self, from: data)
    }
}

public enum SourceScanError: LocalizedError, Equatable {
    case parseFailed
    case reduceEmpty
    public var errorDescription: String? {
        switch self {
        case .parseFailed: return "解析失败"
        case .reduceEmpty: return "归并内容为空"
        }
    }
}
import Foundation

/// 未回收伏笔（续写档案专用）：续写蓝图优先安排回收
public struct CanonThread: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var title: String
    public var detail: String
    public var plantedChapter: Int?
    public var participants: [String] = []

    public init(title: String, detail: String, plantedChapter: Int? = nil, participants: [String] = []) {
        self.title = title; self.detail = detail
        self.plantedChapter = plantedChapter; self.participants = participants
    }

    public enum CodingKeys: String, CodingKey { case id, title, detail, plantedChapter, participants }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        plantedChapter = try c.decodeIfPresent(Int.self, forKey: .plantedChapter)
        participants = try c.decodeIfPresent([String].self, forKey: .participants) ?? []
    }
}
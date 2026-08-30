import XCTest
@testable import ZhiMingCore

/// 性能回归（diagnosing-bugs 反馈回路）：
/// 缺陷——S4 查重对每个候选都重建一次全本 n-gram 集合（`hasViolation` → `ngrams(of: original)`），
/// 大样本（整本书）下多示范/多证据会重复重建十几次，秒级卡顿 + 内存峰值。
/// 回路：带多示范/多证据的完整 checkAndFix 流程，比例与预算双重断言。
final class StylePerfTests: XCTestCase {
    private let sourceText = String(
        repeating: "夜色像一块浸了水的绒布压在巷口，脚步声散进雨里，他说走吧，灯还亮着。",
        count: 7000)   // ≈ 238k 字符

    private lazy var analysisJSON = """
    {"narrative_voice":{"temperature":"冷峻"},
     "sentence_syntax":{"shape":"短句主导"},
     "diction":{"register":"口语"},
     "scene_rhythm":{"openings":"直接入戏"},
     "dialogue":{"subtext_level":"高潜台词"},
     "emotion":{"directness":"移置"},
     "anti_ai":{"forbidden_patterns":["说明腔"]},
     "evidence":[\(evidenceItems)]
    }
    """

    /// 6 条证据（均含与原文 8 字以上重合 → 全部触发查重路径）
    private var evidenceItems: String {
        (0..<6).map { #"{"trait":"观察\#($0)","snippet":"脚步声散进雨里，他说走吧","confidence":"high"}"# }.joined(separator: ",")
    }

    private lazy var cardJSON = """
    {"name":"冷雨","tags":["冷峻"],"fingerprint_summary":"短句。",
     "must_rules":["短句为主"],"avoid_rules":["排比"],
     "examples":[\(exampleItems)]}
    """

    /// 6 个示范（前 3 个与原文重合触发修正请求，修正响应也重合 → 丢弃路径）
    private var exampleItems: String {
        (0..<6).map { i in
            let styled = i < 3 ? "他说：「走吧。」脚步声散进雨里。" : "完全原创的示范句\(i)，毫无重合。"
            return #"{"plain":"p\#(i)","styled":"\#(styled)","principle":"外化"}"#
        }.joined(separator: ",")
    }

    private lazy var fixJSON: String = {
        let items = (0..<3).map { i in
            #"{"index":\#(i),"styled":"他说：「走吧。」脚步声散进雨里。","principle":"环境"}"#
        }.joined(separator: ",")
        return "[\(items)]"
    }()

    /// 缝隙级回归：整段蒸馏流程（含 S4 多候选查重）必须在预算内完成。
    /// 修复前：证据 6 + 示范 6 + 修正后复检 6 + 修正候选 3 ≈ 21 次全本索引重建 → 远超预算（红）。
    /// 修复后：只建 1 次索引 → 远低于预算（绿）。
    func testCheckAndFixCompletesWithinBudget() async throws {
        let client = MockLLMClient(responses: [analysisJSON, cardJSON, fixJSON])
        let service = StyleDistillationService(client: client, config: GenerationConfig(temperature: 0.3, maxTokens: 4096))

        let t0 = Date()
        var profile: StyleProfile?
        for try await event in service.events(sourceText: sourceText, sourceNote: "《大书》",
                                              analyzeSystem: "分析", cardSystem: "汇总", fixSystem: "修正") {
            if case .completed(let p) = event { profile = p }
        }
        let elapsed = Date().timeIntervalSince(t0)
        XCTAssertNotNil(profile)
        // 预算：修复路径 ≈ 一次建索引（约 0.3-0.8s）+ 廉价查询；给 2.5s 余量。
        XCTAssertLessThan(elapsed, 2.5,
                          "S4 查重疑似在重复重建全本索引，耗时 \(elapsed)s")
    }

    /// 单元性质：多候选查询复用一次构建的索引，开销远低于逐候选重建
    func testNgramIndexReuseWins() {
        let candidates = (0..<12).map { i in
            "完全不同的候选示范句\(i)，用词与原文没有任何连续重合。" + String(repeating: "异", count: 24)
        }
        let t0 = Date()
        for candidate in candidates {
            _ = StyleMetrics.hasViolation(candidate, against: sourceText)
        }
        let direct = Date().timeIntervalSince(t0)

        let t1 = Date()
        let index = StyleMetrics.ngramIndex(of: sourceText)
        for candidate in candidates {
            _ = index.hasViolation(candidate)
        }
        let indexed = Date().timeIntervalSince(t1)
        XCTAssertLessThan(indexed * 5, direct,
                          "多候选查重应复用索引：direct=\(direct)s indexed=\(indexed)s")
    }

    func testIndexAgreesWithFreeFunction() {
        let original = "他缓缓推开那扇沉重的木门走进房间，屋里一片漆黑。"
        let index = StyleMetrics.ngramIndex(of: original)
        let copied = "夜里他缓缓推开那扇沉重的木门走进房间，四下无人。"
        let clean = "夜色沉沉，门轴发出一声轻响，他侧身而入。"
        XCTAssertEqual(index.hasViolation(copied), StyleMetrics.hasViolation(copied, against: original))
        XCTAssertEqual(index.hasViolation(clean), StyleMetrics.hasViolation(clean, against: original))
        XCTAssertEqual(
            index.violations(in: [copied, clean]),
            StyleMetrics.ngramViolations(in: [copied, clean], against: original))
    }
}

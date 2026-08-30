import XCTest
@testable import ZhiMingCore

/// 卷名/章节标题写回的宽容匹配回归（用户报告：生成全部卷纲后仍提示生成卷纲）。
/// 根因：applyVolumeBatch 按卷名逐字相等匹配，模型返回的卷名有一丝差异
/// （全角冒号/书名号/丢前缀）就静默跳过 → 该卷永远缺卷纲 → 「生成下一批卷纲」
/// 按钮与进度提示永远挂着。章节标题精确匹配存在同类隐患，一并覆盖。
final class CreationNameMatchTests: XCTestCase {
    /// 三卷蓝图：卷名含空格（真实结构的常见形态）
    private func makeBlueprint() -> NovelBlueprint {
        var bp = NovelBlueprint()
        bp.title_suggestion = "雾港来信"
        bp.volumes = [
            BlueprintVolume(name: "第一卷 雾起", chapters: [
                BlueprintChapter(title: "死信"),
                BlueprintChapter(title: "旧档"),
            ]),
            BlueprintVolume(name: "第二卷 潮落", chapters: [
                BlueprintChapter(title: "潜入"),
            ]),
            BlueprintVolume(name: "第三卷 归岸", chapters: [
                BlueprintChapter(title: "对峙"),
            ]),
        ]
        return bp
    }

    // MARK: 卷纲批次

    func testVolumeBatchToleratesNameVariants() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        let outcome = engine.settle(kind: .volumeBatch, raw: """
        [{"name": "第一卷：雾起", "outline": "A卷纲"},
         {"name": "「第二卷」潮落", "outline": "B卷纲"}]
        """)

        XCTAssertNil(outcome.error)
        let bp = engine.state.blueprint!
        XCTAssertEqual(bp.volumes[0].outline, "A卷纲", "全角冒号变体应命中第一卷")
        XCTAssertEqual(bp.volumes[1].outline, "B卷纲", "书名号变体应命中第二卷")
        XCTAssertTrue(outcome.message?.contains("进度 2/3") == true)
    }

    func testAllBatchesWithVariantsReachAllDone() {
        // 用户症状复现：分批生成完全部卷纲后，提示应为「卷纲已全部生成（3/3）」
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        let first = engine.settle(kind: .volumeBatch, raw: """
        [{"name": "第一卷：雾起", "outline": "A"}, {"name": "第二卷 潮落", "outline": "B"}]
        """)
        let second = engine.settle(kind: .volumeBatch, raw: #"[{"name": "第三卷 归岸", "outline": "C"}]"#)

        XCTAssertEqual(engine.state.blueprint!.volumes.filter { $0.outline?.isEmpty == false }.count, 3)
        XCTAssertTrue(second.message?.contains("卷纲已全部生成（3/3）") == true,
                      "实际消息：\(second.message ?? "nil")")
        _ = first
    }

    func testDroppedPrefixStillMatchesUniqueVolume() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        // 模型只回卷名主体「归岸」——唯一包含关系可定位第三卷
        let outcome = engine.settle(kind: .volumeBatch, raw: #"[{"name": "归岸", "outline": "C"}]"#)
        XCTAssertEqual(engine.state.blueprint!.volumes[2].outline, "C")
        XCTAssertTrue(outcome.message?.contains("进度 1/3") == true)
    }

    func testAmbiguousSubstringDoesNotWrite() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        var bp = makeBlueprint()
        bp.volumes.append(BlueprintVolume(name: "番外卷 归岸外传", chapters: [BlueprintChapter(title: "番外")]))
        engine.state.blueprint = bp

        // 「归岸」同时包含命中两个卷 → 有歧义不写入（宁缺勿错）
        let outcome = engine.settle(kind: .volumeBatch, raw: #"[{"name": "归岸", "outline": "C"}]"#)
        XCTAssertNil(outcome.error)
        let outlines = engine.state.blueprint!.volumes.compactMap { $0.outline }
        XCTAssertTrue(outlines.isEmpty, "歧义匹配应被跳过，实际写入了 \(outlines)")
        XCTAssertTrue(outcome.message?.contains("进度 0/4") == true)
    }

    func testExactMatchStillWorks() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        let outcome = engine.settle(kind: .volumeBatch, raw: #"[{"name": "第一卷 雾起", "outline": "A"}]"#)
        XCTAssertEqual(engine.state.blueprint!.volumes[0].outline, "A")
        XCTAssertTrue(outcome.message?.contains("进度 1/3") == true)
    }

    // MARK: 细纲批次（章节标题同类隐患）

    func testChapterBatchToleratesTitleVariants() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        let outcome = engine.settle(kind: .chapterBatch, raw: """
        [{"title": "「死信」", "detailed_outline": "死信细纲"},
         {"title": "潜入。", "detailed_outline": "潜入细纲"}]
        """)

        XCTAssertNil(outcome.error)
        let chapters = engine.state.blueprint!.volumes.flatMap(\.chapters)
        XCTAssertEqual(chapters.first { $0.title == "死信" }?.detailed_outline, "死信细纲")
        XCTAssertEqual(chapters.first { $0.title == "潜入" }?.detailed_outline, "潜入细纲")
    }
}

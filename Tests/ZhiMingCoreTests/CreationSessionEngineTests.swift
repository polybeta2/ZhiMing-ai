import XCTest
@testable import ZhiMingCore

/// 立项状态机重放测试（第三步）：用 Mock 流事件按 SSE 方式拼接 raw，
/// 重放澄清→结构→蓝图→卷纲/细纲批次→章节标题的全链路阶段转换。
/// 解析与转换逻辑在 CreationSessionEngine（纯 Core 类型），行为与 v2.2.1 真机流程一致。
final class CreationSessionEngineTests: XCTestCase {

    // MARK: 造数

    /// 两卷三章的蓝图（卷纲/细纲均未生成）
    private func makeBlueprint() -> NovelBlueprint {
        var bp = NovelBlueprint()
        bp.title_suggestion = "雾港来信"
        bp.synopsis = "一封来自死者的信"
        bp.style_guide = "冷峻克制"
        bp.volumes = [
            BlueprintVolume(name: "第一卷", chapters: [
                BlueprintChapter(title: "死信"),
                BlueprintChapter(title: "旧档"),
            ]),
            BlueprintVolume(name: "第二卷", chapters: [
                BlueprintChapter(title: "潜入"),
            ]),
        ]
        return bp
    }

    /// 把 JSON 按固定宽度切块再拼接——模拟流式 content delta 的到达方式（与 VM 的 raw 累积一致）
    private func chunked(_ s: String, width: Int = 7) -> String {
        let chars = Array(s)
        var parts: [String] = []
        var i = 0
        while i < chars.count {
            parts.append(String(chars[i..<min(i + width, chars.count)]))
            i += width
        }
        return parts.joined()
    }

    /// 断言 nextStep == .requestStructure
    private func assertRequestStructure(_ outcome: CreationSettleOutcome,
                                        file: StaticString = #filePath, line: UInt = #line) {
        if case .requestStructure? = outcome.nextStep { return }
        XCTFail("期望 nextStep == requestStructure，实际 \(String(describing: outcome.nextStep))", file: file, line: line)
    }

    // MARK: Mock 流 → raw 累积（与 VM stream() 相同的拼接方式）

    /// 复用 LLMClientTests 的 Mock 契约：reasoning 不进正文，content 按序拼接
    func testStreamEventsAssembleRawThenSettle() async throws {
        struct MockLLMClient: LLMClient {
            var script: [StreamEvent]
            public func streamChat(messages: [LLMMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamEvent, Error> {
                let script = self.script
                return AsyncThrowingStream { continuation in
                    let task = Task {
                        for event in script { continuation.yield(event) }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
            public func testConnection() async throws -> String { "mock-ok" }
        }

        let client = MockLLMClient(script: [
            .reasoning("正在判断是否需要追问"),
            .content("{\"enou"),
            .content("gh\": true, \"questions\": []}"),
        ])
        var raw = ""
        for try await event in client.streamChat(messages: [], config: GenerationConfig(temperature: 0.7, maxTokens: 100)) {
            if case .content(let delta) = event { raw += delta }
        }
        XCTAssertEqual(raw, #"{"enough": true, "questions": []}"#)

        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .clarify, raw: raw)
        XCTAssertNil(outcome.error)
        assertRequestStructure(outcome)
        XCTAssertEqual(engine.phase, .collecting)   // 澄清通过不改阶段，由 VM 发起结构请求
    }

    // MARK: 澄清（clarify）

    func testClarifyWithQuestionsAppendsQaText() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .clarify, raw: chunked(
            #"{"enough": false, "questions": ["主角是谁？", "  ", "时代背景？"]}"#))

        XCTAssertNil(outcome.error)
        XCTAssertNil(outcome.nextStep)
        // 空白问题被过滤，qaText 累积编号问题
        XCTAssertEqual(engine.state.qaText, "【问题】\n1. 主角是谁？\n2. 时代背景？\n")
        XCTAssertEqual(outcome.message, "有几个地方想先确认一下：\n\n1. 主角是谁？\n2. 时代背景？")
        XCTAssertEqual(engine.phase, .collecting)
    }

    /// enough=false 但问题为空 → 视为信息足够，自动接结构
    func testClarifyEmptyQuestionsTreatedAsEnough() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .clarify, raw: #"{"enough": false}"#)
        assertRequestStructure(outcome)
        XCTAssertEqual(engine.state.qaText, "")
    }

    func testClarifyGarbageReturnsError() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .clarify, raw: "我觉得可以，不用问了。")
        XCTAssertEqual(outcome.error, "澄清结果解析失败，请重试")
        XCTAssertNil(outcome.message)
        XCTAssertEqual(engine.state.qaText, "")
        XCTAssertEqual(engine.phase, .collecting)
    }

    // MARK: 结构提案（structure）

    func testStructureProposalAdvancesPhase() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .structure, raw: chunked(
            #"{"concept": "完整思路", "volumes": [{"name": "第一卷", "chapter_count": 2}]}"#))
        XCTAssertNil(outcome.error)
        XCTAssertEqual(engine.phase, .proposing)
        XCTAssertEqual(engine.state.proposal?.concept, "完整思路")
        XCTAssertTrue(outcome.message?.contains("已按思路规划出卷章结构") == true)
    }

    func testStructureGarbageKeepsPhase() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        let outcome = engine.settle(kind: .structure, raw: "这不是 JSON")
        XCTAssertEqual(outcome.error, "结构提案解析失败，可发送「重新规划」或修改意见重试")
        XCTAssertEqual(engine.phase, .collecting)
    }

    // MARK: 基础蓝图（foundation）

    func testFoundationSuccessAndFailurePaths() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.phaseRaw = CreationPhase.proposing.rawValue
        engine.state.proposal = StructureProposal(concept: "c", volumes: [])

        let outcome = engine.settle(kind: .foundation, raw: chunked(
            #"{"title_suggestion": "雾港来信", "volumes": [{"name": "第一卷", "chapters": [{"title": "死信"}]}]}"#))
        XCTAssertNil(outcome.error)
        XCTAssertEqual(engine.phase, .blueprintReady)
        XCTAssertEqual(engine.state.blueprint?.volumes.count, 1)
        XCTAssertTrue(outcome.message?.contains("基础蓝图已生成") == true)

        // 失败回退到 proposing（v2.1.2 语义：可发「重新生成」）
        let bad = engine.settle(kind: .foundation, raw: "截断的 { 蓝图")
        XCTAssertEqual(bad.error, "蓝图 JSON 解析失败，可发送「重新生成」")
        XCTAssertEqual(engine.phase, .proposing)
    }

    // MARK: 对话修订（revise）

    func testReviseReplacesBlueprintWithoutPhaseChange() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        engine.state.phaseRaw = CreationPhase.outlining.rawValue

        var revised = makeBlueprint()
        revised.title_suggestion = "改名之作"
        let outcome = engine.settle(kind: .revise, raw: chunked(String(data: try! JSONEncoder().encode(revised), encoding: .utf8)!))
        XCTAssertNil(outcome.error)
        XCTAssertEqual(engine.state.blueprint?.title_suggestion, "改名之作")
        XCTAssertEqual(engine.phase, .outlining)   // 修订不动阶段
        XCTAssertTrue(outcome.message?.contains("已按你的意见修订蓝图") == true)
    }

    // MARK: 卷纲批次（volumeBatch）

    func testVolumeBatchAppliesByMatchAndReportsProgress() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        engine.state.autoContinue = true

        let outcome = engine.settle(kind: .volumeBatch, raw: chunked("""
        [{"name": "第一卷", "outline": "雾起卷纲",
          "emotion_arc": ["压抑", "爆发"],
          "conflict_ladder": [{"level": 1, "obstacle": "排挤", "turning_point": "翻案"}],
          "info_gap": {"start": "不知情", "end": "全知"}},
         {"name": "不存在的卷", "outline": "忽略"}]
        """))

        XCTAssertNil(outcome.error)
        let bp = engine.state.blueprint!
        XCTAssertEqual(bp.volumes[0].outline, "雾起卷纲")
        XCTAssertEqual(bp.volumes[0].emotion_arc, ["压抑", "爆发"])
        XCTAssertEqual(bp.volumes[0].conflict_ladder?.first?.obstacle, "排挤")
        XCTAssertEqual(bp.volumes[0].info_gap?.end, "全知")
        XCTAssertNil(bp.volumes[1].outline)            // 未匹配卷不受影响
        XCTAssertTrue(outcome.message?.contains("进度 1/2") == true)
        XCTAssertTrue(outcome.autoNext)                // 开关开且 1/2 < 2
    }

    func testVolumeBatchAllDoneMessageAndNoAutoNext() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        engine.state.autoContinue = true

        let first = engine.settle(kind: .volumeBatch, raw: #"[{"name": "第一卷", "outline": "A"}]"#)
        XCTAssertTrue(first.autoNext)
        let second = engine.settle(kind: .volumeBatch, raw: #"[{"name": "第二卷", "outline": "B"}]"#)
        XCTAssertTrue(second.message?.contains("卷纲已全部生成（2/2）") == true)
        XCTAssertFalse(second.autoNext)                // 无剩余，不再自动续跑
    }

    func testVolumeBatchGarbageReturnsError() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        let outcome = engine.settle(kind: .volumeBatch, raw: "残缺 [")
        XCTAssertEqual(outcome.error, "卷纲批次解析失败，可重新生成本批")
    }

    // MARK: 细纲批次（chapterBatch）

    func testChapterBatchAppliesOutlinesSceneCardsAndForeshadows() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        let outcome = engine.settle(kind: .chapterBatch, raw: chunked("""
        [{"title": "死信", "detailed_outline": "收信与疑惑",
          "scene_cards": [{"goal": "拿到信", "obstacle": "邮差拦路", "hook": "火漆印"}],
          "foreshadowings": [{"title": "火漆印", "detail": "来自三年前", "reveal_in": "旧档"}]},
         {"title": "不存在的章", "detailed_outline": "忽略"}]
        """))

        XCTAssertNil(outcome.error)
        let bp = engine.state.blueprint!
        XCTAssertEqual(bp.volumes[0].chapters[0].detailed_outline, "收信与疑惑")
        XCTAssertEqual(bp.volumes[0].chapters[0].scene_cards?.first?.goal, "拿到信")
        XCTAssertEqual(bp.volumes[0].chapters[0].foreshadowings?.first?.reveal_in, "旧档")
        XCTAssertNil(bp.volumes[1].chapters[0].detailed_outline)   // 未匹配章不受影响
        XCTAssertTrue(outcome.message?.contains("进度 1/3") == true)

        // 补齐剩余两章 → 全部完成文案
        let second = engine.settle(kind: .chapterBatch, raw: """
        [{"title": "旧档", "detailed_outline": "查档"}, {"title": "潜入", "detailed_outline": "夜探"}]
        """)
        XCTAssertTrue(second.message?.contains("细纲已全部生成（3/3）") == true)
        XCTAssertFalse(second.autoNext)
    }

    func testChapterBatchGarbageReturnsError() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()
        let outcome = engine.settle(kind: .chapterBatch, raw: "不是数组")
        XCTAssertEqual(outcome.error, "细纲批次解析失败，可重新生成本批")
    }

    // MARK: 章节标题批次（chapterNames）

    func testChapterNamesWrittenToTargetVolume() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        // 标题多于章数：多余截断
        let outcome = engine.settle(kind: .chapterNames, raw: chunked(
            #"[{"title": "雾夜"}, {"title": "浮尸"}, {"title": "多余标题"}]"#,
            width: 5), chapterNameTargetIndex: 0)
        XCTAssertNil(outcome.error)
        let bp = engine.state.blueprint!
        XCTAssertEqual(bp.volumes[0].chapters.map(\.title), ["雾夜", "浮尸"])
        XCTAssertTrue(outcome.message?.contains("已生成《第一卷》2 个章节标题") == true)
    }

    func testChapterNamesEmptyTitlesAndInvalidTarget() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        engine.state.blueprint = makeBlueprint()

        let empty = engine.settle(kind: .chapterNames, raw: #"[{"title": "  "}]"#, chapterNameTargetIndex: 0)
        XCTAssertEqual(empty.error, "解析到空章节标题，可重新生成")

        let invalid = engine.settle(kind: .chapterNames, raw: #"[{"title": "雾夜"}]"#, chapterNameTargetIndex: 9)
        XCTAssertEqual(invalid.message, "章节标题已生成完毕")
        XCTAssertNil(invalid.error)
    }

    // MARK: 全链路重放（澄清→结构→蓝图→卷纲→细纲，全程 SSE 分块）

    func testFullPipelineReplay() {
        var engine = CreationSessionEngine(brief: "雾港探案：一封来自死者的信")

        // 1) 澄清：信息足够 → 建议接结构
        var out = engine.settle(kind: .clarify, raw: chunked(#"{"enough": true, "questions": []}"#))
        assertRequestStructure(out)

        // 2) 结构提案
        out = engine.settle(kind: .structure, raw: chunked(
            #"{"concept": "侦探收到的信署名是死者", "volumes": [{"name": "第一卷", "chapter_count": 2}, {"name": "第二卷", "chapter_count": 1}]}"#))
        XCTAssertEqual(engine.phase, .proposing)

        // 3) 基础蓝图（角色/世界观/两卷三章，卷纲细纲留空）
        out = engine.settle(kind: .foundation, raw: chunked("""
        {"title_suggestion": "雾港来信", "synopsis": "一封来自死者的信", "style_guide": "冷峻",
         "characters": [{"name": "沈屿", "role": "主角"}],
         "worldbuilding": [{"category": "地点", "name": "雾港", "content": "终年多雾"}],
         "volumes": [
           {"name": "第一卷", "chapters": [{"title": "死信"}, {"title": "旧档"}]},
           {"name": "第二卷", "chapters": [{"title": "潜入"}]}
         ]}
        """))
        XCTAssertEqual(engine.phase, .blueprintReady)
        XCTAssertEqual(engine.outlineProgress.volumeTotal, 2)
        XCTAssertEqual(engine.outlineProgress.volumeDone, 0)
        XCTAssertEqual(engine.outlineProgress.outlineTotal, 3)

        // 4) 卷纲一批补齐（chapters key 缺省也能解码）
        out = engine.settle(kind: .volumeBatch, raw: chunked(
            #"[{"name": "第一卷", "outline": "雾起"}, {"name": "第二卷", "outline": "潮落"}]"#))
        XCTAssertTrue(out.message?.contains("卷纲已全部生成（2/2）") == true)
        XCTAssertEqual(engine.outlineProgress.volumeDone, 2)

        // 5) 细纲两批补齐
        out = engine.settle(kind: .chapterBatch, raw: chunked(
            #"[{"title": "死信", "detailed_outline": "收信"}, {"title": "旧档", "detailed_outline": "查档"}]"#))
        XCTAssertTrue(out.message?.contains("进度 2/3") == true)
        out = engine.settle(kind: .chapterBatch, raw: chunked(
            #"[{"title": "潜入", "detailed_outline": "夜探纸坊"}]"#))
        XCTAssertTrue(out.message?.contains("细纲已全部生成（3/3）") == true)

        // 6) 落库映射：章节、卷纲、细纲全部就位
        let novel = Novel(title: "临时", synopsis: "")
        CreationSessionEngine.applyBlueprint(engine.state.blueprint!, into: novel)
        XCTAssertEqual(novel.title, "雾港来信")
        XCTAssertEqual(novel.volumes.count, 2)
        XCTAssertEqual(novel.volumes[0].outline, "雾起")
        XCTAssertEqual(novel.volumes[0].chapters[1].detailedOutline, "查档")
        XCTAssertEqual(novel.sortedVolumes[1].chapters[0].sceneCards, nil)
    }

    // MARK: 批次目标选取与伏笔揭晓注入

    func testPendingTargetsAndForeshadowReveals() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        var bp = makeBlueprint()
        bp.volumes[0].outline = "雾起卷纲"
        bp.volumes[0].chapters[0].foreshadowings = [
            BlueprintForeshadow(title: "火漆印", detail: "来自三年前", reveal_in: "旧档"),
        ]
        engine.state.blueprint = bp

        // 卷纲目标：跳过已生成的第一卷
        XCTAssertEqual(engine.pendingVolumes(prefix: 5), ["第二卷"])
        // 细纲目标：三章按序全部待生成
        XCTAssertEqual(engine.pendingChapters(prefix: 2), ["死信", "旧档"])

        // batchContext：命中卷给全量卷纲 + 本批揭晓伏笔 + 后续章节
        let context = engine.batchContext(targets: ["旧档"])
        XCTAssertTrue(context.contains("【第一卷·卷纲】雾起卷纲"))
        XCTAssertTrue(context.contains("【需在本批揭晓的伏笔】"))
        XCTAssertTrue(context.contains("「火漆印」→ 应在《旧档》揭晓（埋设于《死信》）：来自三年前"))
        XCTAssertTrue(context.contains("【后续章节】"))
        XCTAssertTrue(context.contains("潜入"))
    }

    // MARK: 展示策略与 JSON 导出

    func testNeedsRawDisplay() {
        XCTAssertTrue(CreationSessionEngine.needsRawDisplay(.foundation))
        XCTAssertTrue(CreationSessionEngine.needsRawDisplay(.revise))
        XCTAssertTrue(CreationSessionEngine.needsRawDisplay(.structure))
        XCTAssertFalse(CreationSessionEngine.needsRawDisplay(.clarify))
        XCTAssertFalse(CreationSessionEngine.needsRawDisplay(.volumeBatch))
        XCTAssertFalse(CreationSessionEngine.needsRawDisplay(.chapterBatch))
        XCTAssertFalse(CreationSessionEngine.needsRawDisplay(.chapterNames))
    }

    func testBlueprintAndProposalJSONExport() {
        var engine = CreationSessionEngine(brief: "雾港探案")
        XCTAssertNil(engine.blueprintJSON())
        XCTAssertNil(engine.proposalJSON())

        engine.state.proposal = StructureProposal(concept: "c", volumes: [])
        engine.state.blueprint = makeBlueprint()
        XCTAssertTrue(engine.blueprintJSON()?.contains("雾港来信") == true)
        XCTAssertTrue(engine.proposalJSON()?.contains("完整") == false)   // concept 是 "c"
    }

    // MARK: 落库映射（applyBlueprint）

    func testApplyBlueprintIntoNovel() {
        var bp = NovelBlueprint()
        bp.title_suggestion = "雾港来信"
        bp.synopsis = "信"
        bp.perspective = "第三人称限知"
        bp.style_guide = "冷峻"
        bp.theme = "悬疑"
        bp.characters = [BlueprintCharacter(name: "沈屿", role: "主角", goal: "查清寄信人"),
                         BlueprintCharacter(name: "   ")]        // 空白名丢弃
        bp.worldbuilding = [BlueprintWorld(category: "不存在的分类", name: "雾港", content: "多雾"),
                            BlueprintWorld(category: "地点", name: "旧纸坊", content: "AI 版")]
        bp.volumes = [BlueprintVolume(
            name: "第一卷",
            emotion_arc: ["压抑", "  "],
            conflict_ladder: [BlueprintConflictRung(obstacle: "排挤"), BlueprintConflictRung()],
            info_gap: BlueprintInfoGap(start: "不知", end: "全知"),
            chapters: [
                BlueprintChapter(title: "死信", detailed_outline: "收信",
                                 scene_cards: [BlueprintSceneCard(goal: "拿信"),
                                               BlueprintSceneCard()]),   // 空卡丢弃
                BlueprintChapter(detailed_outline: "  "),                // 空白细纲 → nil，默认标题
            ])]

        let novel = Novel(title: "临时", synopsis: "")
        novel.worldEntries = [WorldEntry(category: "地点", name: "旧纸坊", content: "用户手输版")]
        CreationSessionEngine.applyBlueprint(bp, into: novel)

        XCTAssertEqual(novel.title, "雾港来信")
        XCTAssertEqual(novel.synopsis, "信")
        XCTAssertEqual(novel.perspective, "第三人称限知")
        XCTAssertEqual(novel.styleGuide, "冷峻")
        XCTAssertEqual(novel.genre, "悬疑")
        XCTAssertEqual(novel.characters.count, 1)
        XCTAssertEqual(novel.characters[0].currentGoal, "查清寄信人")
        XCTAssertEqual(novel.characters[0].background, "书中定位：主角")

        // 世界观合并：同名保留用户手输版；未知分类兜底「其他」
        XCTAssertEqual(novel.worldEntries.count, 2)
        XCTAssertEqual(novel.worldEntries.first?.content, "用户手输版")
        XCTAssertEqual(novel.worldEntries.last?.category, "其他")

        let volume = novel.volumes[0]
        XCTAssertEqual(volume.name, "第一卷")
        XCTAssertEqual(volume.emotionArc, ["压抑"])                     // 空白过滤
        XCTAssertEqual(volume.conflictLadder?.count, 1)                // obstacle 空的阶梯丢弃
        XCTAssertEqual(volume.conflictLadder?.first?.level, 1)         // 缺 level → 序号补位
        XCTAssertEqual(volume.infoGap?.start, "不知")

        XCTAssertEqual(volume.chapters.count, 2)
        XCTAssertEqual(volume.chapters[0].title, "死信")
        XCTAssertEqual(volume.chapters[0].sceneCards?.count, 1)
        XCTAssertEqual(volume.chapters[1].title, "第2章")
        XCTAssertNil(volume.chapters[1].detailedOutline)
    }
}

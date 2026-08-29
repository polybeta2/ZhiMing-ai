import Foundation
@testable import ZhiMingCore

/// 测试共用的小对象图构造（不触真实存储，纯内存）
enum Fixtures {
    /// 三章小书：卷一（两章，带摘要）+ 卷二（目标章）
    static func makeNovel() -> Novel {
        let novel = Novel(title: "雾港来信", synopsis: "一封来自死去之人的信")
        novel.styleGuide = "冷峻克制的探案文风，短句为主。"

        let v1 = Volume(name: "第一卷 雾起", sortOrder: 1, outline: "雾港连环信件案的开端与排查。")
        let c1 = Chapter(title: "第一章 死信", sortOrder: 1)
        c1.content = String(repeating: "码头晨雾未散。", count: 50)
        c1.summary = ChapterSummary(summaryText: "沈屿收到一封署名亡者的信。", keyFacts: ["信件笔迹与亡者一致", "邮戳来自三年前"])
        let c2 = Chapter(title: "第二章 旧档", sortOrder: 2)
        c2.content = String(repeating: "档案馆的灯管嗡嗡作响。", count: 60)
        c2.summary = ChapterSummary(summaryText: "沈屿查出信纸产自分崩的旧纸坊。", keyFacts: ["旧纸坊十年前烧毁"])
        v1.chapters = [c1, c2]

        let v2 = Volume(name: "第二卷 潮落", sortOrder: 2, outline: "真相逼近，雾更浓了。")
        let c3 = Chapter(title: "第三章 潜入", sortOrder: 1)
        c3.content = String(repeating: "潮水拍打着堤岸。", count: 80)
        c3.detailedOutline = "沈屿夜探纸坊旧址，发现仍在运转的印刷机。"
        c3.sceneCards = [
            SceneCard(goal: "拿到印刷批次记录", obstacle: "看守犬与铁丝网", hook: "印刷机是热的"),
        ]
        v2.chapters = [c3]

        novel.volumes = [v1, v2]
        v1.novel = novel
        v2.novel = novel
        c1.volume = v1
        c2.volume = v1
        c3.volume = v2

        let char = CharacterCard(name: "沈屿")
        char.aliases = ["沈探长"]
        char.personality = "执拗，失眠，靠黑咖啡续命"
        char.currentGoal = "查清寄信人身份"
        char.currentLocation = "雾港旧城区"
        char.isSceneRelevant = true
        novel.characters = [char]

        let world = WorldEntry(category: "地点", name: "旧纸坊", content: "十年前烧毁的造纸工坊，传闻夜里仍有机器声。")
        novel.worldEntries = [world]

        novel.foreshadowings = [
            Foreshadowing(title: "烧毁的印刷机", detail: "废墟里的机器为什么是热的",
                          plantedVolumeIndex: 1, plantedChapterOrder: 1,
                          plannedResolve: "第二卷末揭示有人重启作坊", status: .open),
        ]
        return novel
    }

    /// 目标章：卷二第一章（对应 makeNovel 的 c3）
    static func targetChapter(in novel: Novel) -> Chapter {
        novel.sortedVolumes[1].sortedChapters[0]
    }
}

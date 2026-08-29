import Foundation

#if DEBUG
/// 仅 DEBUG：注入演示数据，便于预览与真机体验
public enum SeedData {

    /// 注入演示作品（1 卷 3 章、2 角色、2 世界观条目）；仅在空库时调用
    @MainActor
    public static func inject(into store: AppStore) {
        let novel = Novel(title: "雾港来信", synopsis: "十九世纪末的雾港，一名失忆的灯塔看守人收到一封写给自己的讣告。")
        novel.genre = "悬疑/哥特"
        novel.perspective = "第三人称限知"
        novel.styleGuide = "冷峻克制的哥特笔调，多用海雾、灯塔与钟声意象；对话简短、留白多。"
        novel.accentColorHex = "#4D5C91"

        let volume = Volume(name: "第一卷·讣告", sortOrder: 1, outline: "看守人伊恩收到讣告后追查自己的过去，逐步发现灯塔下掩埋的走私网络。")
        volume.novel = novel
        novel.volumes.append(volume)

        let c1 = Chapter(title: "第 1 章·雾中的邮差", sortOrder: 1)
        c1.detailedOutline = "浓雾夜，邮差送来一封讣告，收件人正是伊恩自己；他决定下山进城查证。"
        c1.content = "雾从海面涌上来，把灯塔的白色塔身一寸寸吞掉。伊恩数着钟声，直到第七下，才听见山道上的脚步声。"
        c1.wordCount = c1.content.count
        c1.volume = volume
        volume.chapters.append(c1)

        let c2 = Chapter(title: "第 2 章·不存在的葬礼", sortOrder: 2)
        c2.detailedOutline = "伊恩在城里打听讣告落款的殡仪馆，发现那家馆三年前就已烧毁。"
        c2.volume = volume
        volume.chapters.append(c2)

        let c3 = Chapter(title: "第 3 章·守塔人名册", sortOrder: 3)
        c3.detailedOutline = "港务处的名册上，前任守塔人的名字与伊恩一模一样，死亡日期是三个月后。"
        c3.volume = volume
        volume.chapters.append(c3)

        let ian = CharacterCard(name: "伊恩·摩尔")
        ian.aliases = ["守塔人"]
        ian.personality = "谨慎、寡言，对声音与光线异常敏感"
        ian.background = "自称三年前来到雾港，此前的记忆一片空白"
        ian.currentGoal = "查明讣告来历与自己失忆的真相"
        ian.currentLocation = "灯塔"
        ian.physicalState = "健康，左手有旧烫伤疤痕"
        ian.mentalState = "警觉，偶发既视感"
        ian.isSceneRelevant = true
        ian.novel = novel
        novel.characters.append(ian)

        let postman = CharacterCard(name: "老邮差芬恩")
        postman.personality = "絮叨，嗜酒，但消息灵通"
        postman.currentGoal = "送完最后一年邮件后退休"
        postman.currentLocation = "雾港城区"
        postman.mentalState = "对伊恩隐隐回避"
        postman.isSceneRelevant = true
        postman.novel = novel
        novel.characters.append(postman)

        let w1 = WorldEntry(category: "地点", name: "雾港", content: "终年浓雾的港口小镇，以灯塔与走私旧事闻名；钟声是雾天的计时方式。")
        w1.novel = novel
        novel.worldEntries.append(w1)

        let w2 = WorldEntry(category: "规则", name: "雾天七钟", content: "雾夜灯塔每半小时敲钟一次，第七声后山道封闭，任何人不得上下山。")
        w2.novel = novel
        novel.worldEntries.append(w2)

        store.novels.append(novel)
    }
}
#endif

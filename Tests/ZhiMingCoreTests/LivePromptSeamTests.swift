import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import ZhiMingCore

/// 真实提示词冒烟检查（手动运行，不入常规回归）：
/// 用环境变量注入测试 API（绝不把 Key 写进任何文件）：
///   ZM_LIVE_KEY=sk-xxx [ZM_LIVE_BASE=...] [ZM_LIVE_MODEL=...]
///   wsl -d Ubuntu bash -lc "cd /mnt/d/iOS/ZhiMing && ZM_LIVE_KEY=... swift test --skip-build --filter LivePromptSeamTests"
/// 未设置 ZM_LIVE_KEY 时整个用例自动跳过。
/// 说明：Linux 上 OpenAICompatibleClient 不可用（无 URLSession.bytes），这里用一次性
/// 非流式 /chat/completions 调用——验证对象是提示词与衔接质量，与流式无关。
final class LivePromptSeamTests: XCTestCase {
    private func makeNovel() -> Novel {
        let novel = Novel(title: "雾港来信", synopsis: "一封来自死去之人的信")
        novel.styleGuide = "冷峻克制的探案文风，短句为主，情绪藏在物件与动作里。"
        let v1 = Volume(name: "第一卷", sortOrder: 1)

        // 上一章：结尾停在一个具体时刻（捏着信纸、雨未停、电话响起）
        let c1 = Chapter(title: "第一章 死信", sortOrder: 1)
        c1.content = """
        邮差把信塞进门缝的时候，沈屿正在擦他那支旧钢笔。
        信封上没有邮戳，收信人一栏是他自己的名字，字迹却属于一个死了三年的人。
        他把信纸抽出来，只看了一行，窗外的雨忽然大了起来。
        沈屿捏着信纸的手停在半空，桌上的电话在这时响了。
        """
        // 撰写目标：第二章（细纲给出本章事件）
        let c2 = Chapter(title: "第二章 旧档", sortOrder: 2)
        c2.detailedOutline = "沈屿接完电话赶到档案馆，调出十年前的印刷批次记录，发现关键一页被人抽走；看守老人欲言又止，暗示当年有人来过。"
        // 下一章：细纲开头限定第三章的开场事件
        let c3 = Chapter(title: "第三章 潜入", sortOrder: 3)
        c3.detailedOutline = "夜里沈屿潜回纸坊，看见印刷机仍在运转，有人比他先到了一步，地上留着一枚湿脚印。"

        v1.chapters = [c1, c2, c3]
        novel.volumes = [v1]
        v1.novel = novel
        c1.volume = v1
        c2.volume = v1
        c3.volume = v1
        return novel
    }

    func testLiveWritingSeam() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["ZM_LIVE_KEY"], !key.isEmpty else {
            throw XCTSkip("未设置 ZM_LIVE_KEY，跳过真实 API 检查")
        }
        let base = URL(string: env["ZM_LIVE_BASE"] ?? "https://ai.zyyun.xyz/v1")!
        let model = env["ZM_LIVE_MODEL"] ?? "gemini-3.7-flash"

        let novel = makeNovel()
        let target = try XCTUnwrap(novel.volumes.first?.chapters[1])

        // 与 App 完全一致的装配路径（async 上下文须用 MainActor.run，assumeIsolated 仅限主线程同步方法）
        let (system, user) = try await MainActor.run {
            let context = ContextBuilder.buildContinueContext(chapter: target, novel: novel, budgetChars: 60_000)
            let assembled = PromptTemplates.writing(context: context, wordTarget: 1200, extra: nil)
            return (assembled[0].content, assembled[1].content)
        }

        // 摘要打印装配结果里的衔接段（人审第一关）
        print("=====PROMPT SECTIONS=====")
        print(user.prefix(1400))
        print("=====END SECTIONS=====")

        // 两种运行模式：
        // ① ZM_LIVE_DUMP=1 → 把完整请求 JSON 写到 /tmp/zm-live-request.json（站点屏蔽大陆 IP 时，
        //    由外部 curl 走代理发送：curl -x http://127.0.0.1:7890 ...）
        // ② 直接调用（海外网络环境）
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": system],
                         ["role": "user", "content": user]],
            "temperature": 0.8,
            "max_tokens": 2400,
            "stream": false,
        ]
        if env["ZM_LIVE_DUMP"] == "1" {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            let path = env["ZM_LIVE_DUMP_PATH"] ?? "/tmp/zm-live-request.json"
            try data.write(to: URL(fileURLWithPath: path))
            print("=====DUMPED=====")
            print(path)
            throw XCTSkip("已 dump 请求到 \(path)，由外部 curl 发送")
        }

        let output = try await chatCompletion(baseUrl: base, key: key, payload: payload)

        print("=====LIVE OUTPUT (\(output.count) chars)=====")
        print(output)
        print("=====END OUTPUT=====")

        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // 硬断言只做最基本的结构性检查（衔接质量由人审输出判断）
        XCTAssertFalse(output.contains("第二章"), "正文不应包含章节标题")
    }

    /// Linux 兼容的一次性 chat completion（completionHandler 桥接 async）
    private func chatCompletion(baseUrl: URL, key: String, payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: baseUrl.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "live", code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "空响应"]))
                }
            }.resume()
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw NSError(domain: "live", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "响应解析失败：\(raw.prefix(300))"])
        }
        return content
    }
}

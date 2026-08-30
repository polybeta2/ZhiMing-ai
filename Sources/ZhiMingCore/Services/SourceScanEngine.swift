import Foundation

public enum SourceScanPhase: String, Equatable { case splitting, mapping, reducing, done, paused }

public enum SourceScanEvent: Equatable {
    case phase(SourceScanPhase)
    case chunkDone(Int)                       // 单块完成（内容序）
    case chunkProgress(done: Int, total: Int)
    case tokenUsage(in: Int, out: Int)
    case reduceText(String)                   // 一段归并产出（阶段摘要）
    case completed(SourceNovelProfile)
}

/// 扫描引擎：顺序 Map 全部块（跳过 done 块）+ 一段归并（按批）+ 二段终归并。
/// 纯值类型 + 闭包回调落地（doneChunkIDs 持久化由调用方实现）；客户端 Mock 即测。
public struct SourceScanEngine {
    public let chunks: [SourceScanChunker.Chunk]
    private let client: LLMClient
    private let mode: ScanMode
    private var doneChunkIDs: Set<Int>
    private let onChunkRequest: (Int, Int) -> Void     // (chunkID, chunkCount) 分配请求前回调，供调用方落 SQLite

    public init(chunks: [SourceScanChunker.Chunk], client: LLMClient, mode: ScanMode,
                doneChunkIDs: Set<Int>, onChunkRequest: @escaping (Int, Int) -> Void) {
        self.chunks = chunks
        self.client = client
        self.mode = mode
        self.doneChunkIDs = doneChunkIDs
        self.onChunkRequest = onChunkRequest
    }

    public func run() -> AsyncThrowingStream<SourceScanEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // ---- Map 阶段：逐块微摘要（跳过 done；网络/解析失败各重试 3 次） ----
                    continuation.yield(.phase(.mapping))
                    var micros: [SourceMicroSummarizer.MicroSummary] = []
                    var tokensIn = 0, tokensOut = 0
                    for (pos, chunk) in self.chunks.enumerated() where !self.doneChunkIDs.contains(pos) {
                        try Task.checkCancellation()
                        self.onChunkRequest(pos, self.chunks.count)
                        let msgs = SourceMicroSummarizer.messages(chunk: chunk.text, chapterMarker: nil)
                        var micro = SourceMicroSummarizer.MicroSummary()
                        var networkFailed = true
                        for _ in 0..<3 {
                            let (reply, drained) = await Self.request(client: self.client, messages: msgs, config: Self.config)
                            networkFailed = !drained
                            if let parsed = try? SourceMicroSummarizer.parse(reply) {
                                micro = parsed
                                networkFailed = false
                                break
                            }
                            // 解析失败或网络错误 → 继续重试
                        }
                        tokensIn += msgs.totalContentChars / 2
                        tokensOut += Self.microChars(micro)
                        if networkFailed {
                            continuation.finish(throwing: LLMError.httpStatus(504, "同人分析网络重试 3 次均失败"))
                            return
                        }
                        continuation.yield(.chunkDone(pos))
                        continuation.yield(.chunkProgress(done: pos + 1, total: self.chunks.count))
                        continuation.yield(.tokenUsage(in: tokensIn, out: tokensOut))
                        micros.append(micro)
                    }
                    guard !Task.isCancelled else { throw CancellationError() }

                    // ---- Reduce 一段：按批 40 条归并为阶段摘要（网络失败重试 3 次） ----
                    continuation.yield(.phase(.reducing))
                    let batchSize = 40
                    var stageSummaries: [String] = []
                    for batchStart in stride(from: 0, to: micros.count, by: batchSize) {
                        try Task.checkCancellation()
                        let slice = Array(micros[batchStart..<min(batchStart + batchSize, micros.count)])
                        let prompt = SourceReducer.batchPrompt(micros: slice, batchChars: 12000)
                        let msgs = [LLMMessage(role: .user, content: prompt)]
                        let (reply, drained) = await Self.retryingRequest(client: self.client, messages: msgs, config: Self.reduceConfig)
                        guard drained else {
                            continuation.finish(throwing: LLMError.httpStatus(504, "同人分析网络重试 3 次均失败"))
                            return
                        }
                        stageSummaries.append(reply)
                        continuation.yield(.reduceText(reply))
                    }

                    // ---- Reduce 二段：终归并为档案（网络失败重试 3 次） ----
                    // 冒烟教训：终归并输出可达 5000+ token，按 Map 的 3000 上限会截断 JSON 导致解析失败
                    let finalMSGS = SourceReducer.finalPrompt(stageSummaries: stageSummaries, characters: [])
                    let (finalRaw, drained) = await Self.retryingRequest(client: self.client, messages: finalMSGS, config: Self.finalConfig)
                    guard drained else {
                        continuation.finish(throwing: LLMError.httpStatus(504, "同人分析网络重试 3 次均失败"))
                        return
                    }
                    let profile = try SourceReducer.parseFinal(finalRaw, fallbackTitle: "同人原作")
                    continuation.yield(.phase(.done))
                    continuation.yield(.completed(profile))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 单次流式请求：聚合 content 事件；返回 (正文拼接, 是否完整读完)
    private static func request(client: LLMClient, messages: [LLMMessage],
                                config: GenerationConfig) async -> (reply: String, drained: Bool) {
        var reply = ""
        do {
            for try await ev in client.streamChat(messages: messages, config: config) {
                if case .content(let d) = ev { reply += d }
            }
            return (reply, true)
        } catch {
            return (reply, false)
        }
    }

    /// 网络重试：最多 3 次，读到流尾即返回
    private static func retryingRequest(client: LLMClient, messages: [LLMMessage],
                                        config: GenerationConfig) async -> (reply: String, drained: Bool) {
        for _ in 0..<3 {
            let (reply, drained) = await request(client: client, messages: messages, config: config)
            if drained { return (reply, true) }
        }
        return ("", false)
    }

    /// 微摘要 token 近似（输出字符数 / 2）
    private static func microChars(_ micro: SourceMicroSummarizer.MicroSummary) -> Int {
        ((try? String(data: JSONEncoder().encode(micro), encoding: .utf8))?.count ?? 0) / 2
    }

    /// Map 阶段：微摘要短小，3000 足够
    private static var config: GenerationConfig { GenerationConfig(temperature: 0.4, maxTokens: 3000) }
    /// 一段归并：阶段摘要可达数千字，放宽到 6000
    private static var reduceConfig: GenerationConfig { GenerationConfig(temperature: 0.4, maxTokens: 6000) }
    /// 终归并：整本档案 JSON 可达 5000+ token，放宽到 8000（冒烟实测 3000 会截断）
    private static var finalConfig: GenerationConfig { GenerationConfig(temperature: 0.3, maxTokens: 8000) }
}
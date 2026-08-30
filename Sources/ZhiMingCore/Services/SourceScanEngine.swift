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
                    // ---- Map 阶段：逐块微摘要（跳过 done） ----
                    continuation.yield(.phase(.mapping))
                    var micros: [SourceMicroSummarizer.MicroSummary] = []
                    var tokensIn = 0, tokensOut = 0
                    for (pos, chunk) in self.chunks.enumerated() where !self.doneChunkIDs.contains(pos) {
                        try Task.checkCancellation()
                        self.onChunkRequest(pos, self.chunks.count)
                        let msgs = SourceMicroSummarizer.messages(chunk: chunk.text, chapterMarker: nil)
                        let (reply, drained) = await Self.request(client: self.client, messages: msgs)
                        tokensIn += msgs.totalContentChars / 2
                        tokensOut += reply.count / 2
                        let micro: SourceMicroSummarizer.MicroSummary
                        if let parsed = try? SourceMicroSummarizer.parse(reply) {
                            micro = parsed
                        } else if drained {
                            // 宽松重试一次 → 仍败降级空摘要（不阻塞）
                            let retry = await Self.request(client: self.client, messages: msgs)
                            if let parsed = try? SourceMicroSummarizer.parse(retry.reply) {
                                micro = parsed
                            } else {
                                micro = SourceMicroSummarizer.MicroSummary()
                            }
                        } else {
                            micro = SourceMicroSummarizer.MicroSummary()
                        }
                        continuation.yield(.chunkDone(pos))
                        continuation.yield(.chunkProgress(done: pos + 1, total: self.chunks.count))
                        continuation.yield(.tokenUsage(in: tokensIn, out: tokensOut))
                        micros.append(micro)
                    }
                    guard !Task.isCancelled else { throw CancellationError() }

                    // ---- Reduce 一段：按批 40 条归并为阶段摘要 ----
                    continuation.yield(.phase(.reducing))
                    let batchSize = 40
                    var stageSummaries: [String] = []
                    for batchStart in stride(from: 0, to: micros.count, by: batchSize) {
                        try Task.checkCancellation()
                        let slice = Array(micros[batchStart..<min(batchStart + batchSize, micros.count)])
                        let prompt = SourceReducer.batchPrompt(micros: slice, batchChars: 12000)
                        let msgs = [LLMMessage(role: .user, content: prompt)]
                        let (reply, _) = await Self.request(client: self.client, messages: msgs)
                        stageSummaries.append(reply)
                        continuation.yield(.reduceText(reply))
                    }

                    // ---- Reduce 二段：终归并为档案 ----
                    let finalMSGS = SourceReducer.finalPrompt(stageSummaries: stageSummaries, characters: [])
                    let (finalRaw, _) = await Self.request(client: self.client, messages: finalMSGS)
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
    private static func request(client: LLMClient, messages: [LLMMessage]) async -> (reply: String, drained: Bool) {
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

    private static var config: GenerationConfig { GenerationConfig(temperature: 0.4, maxTokens: 3000) }
}
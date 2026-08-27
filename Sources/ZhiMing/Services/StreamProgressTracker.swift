import Foundation
import Combine

/// 流式生成进度跟踪：等待首Token → 深度思考 → 输出中
/// 供 UI 展示「正在等待首Token Xs / 深度思考 X字 Xs / 正在输出 X字 Xs」
@MainActor
final class StreamProgressTracker: ObservableObject {
    enum Stage: Equatable { case idle, waitingFirstToken, thinking, outputting }

    @Published private(set) var stage: Stage = .idle
    @Published private(set) var reasoningChars = 0
    @Published private(set) var contentChars = 0
    /// 当前阶段耗时（秒）
    @Published private(set) var elapsed: TimeInterval = 0

    private var stageStart = Date.distantPast
    private var timer: Timer?

    /// 请求发起：进入等待首Token并开始计时
    func begin() {
        reasoningChars = 0
        contentChars = 0
        enter(.waitingFirstToken)
    }

    /// 消费流式事件：首个事件离开等待；reasoning → thinking；content → outputting
    func handle(_ event: StreamEvent) {
        switch event {
        case .reasoning(let delta):
            reasoningChars += delta.count
            if stage != .outputting { enter(.thinking) }
        case .content(let delta):
            contentChars += delta.count
            enter(.outputting)
        }
    }

    /// 流结束/取消：停表归位
    func finish() {
        timer?.invalidate()
        timer = nil
        stage = .idle
        elapsed = 0
    }

    private func enter(_ newStage: Stage) {
        guard stage != newStage else { return }
        stage = newStage
        stageStart = .now
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.stage != .idle else { return }
                self.elapsed = Date().timeIntervalSince(self.stageStart)
            }
        }
    }
}

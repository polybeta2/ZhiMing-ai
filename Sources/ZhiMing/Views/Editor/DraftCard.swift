import SwiftUI

/// AI 草稿卡片：实时流式展示全文；底部三按钮 采纳并入正文 / 重新生成 / 放弃
struct DraftCard: View {
    @ObservedObject var vm: WritingSessionViewModel
    var isRewrite = false
    var onAccept: () -> Void
    var onRegenerate: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            // 被裁剪的上下文段落提示
            if !vm.truncatedSections.isEmpty {
                Label("已省略：\(vm.truncatedSections.joined(separator: "、")) 等段落", systemImage: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let error = vm.errorMessage {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            // 流式状态行：等待首Token / 深度思考（正文输出阶段正常流式展示，隐藏本行）
            if vm.phase == .streaming {
                StreamingStatusView(tracker: vm.progress, showsOutputting: false)
            }

            ScrollView {
                Text(vm.draft.isEmpty && vm.phase == .streaming ? "生成中…" : vm.draft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(vm.draft.isEmpty ? .secondary : .primary)
                    .padding(AppTheme.spacing[2])
            }
            .frame(maxHeight: 220)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.radiusCard))

            if vm.phase == .streaming {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("AI 正在写作…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("停止") { vm.stop() }
                        .font(.footnote)
                }
            } else {
                HStack(spacing: AppTheme.spacing[1]) {
                    Button(role: .destructive) {
                        onDiscard()
                    } label: {
                        Label("放弃", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onRegenerate()
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onAccept()
                    } label: {
                        Label(isRewrite ? "替换原文" : "采纳并入正文", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.draft.isEmpty)
                }
                .font(.footnote)
            }
        }
        .padding(AppTheme.spacing[2])
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard)
                .strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, AppTheme.spacing[2])
    }
}

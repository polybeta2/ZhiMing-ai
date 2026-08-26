import SwiftUI
import UIKit

/// 导出作品弹窗：选择范围与格式，生成临时文件后调起分享面板
struct ExportSheet: View {
    let novel: Novel
    @Environment(\.dismiss) private var dismiss

    @State private var scope: ExportScope = .fullNovel
    @State private var format: ExportFormat = .markdown
    @State private var selectedVolumeID: UUID?
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?
    @State private var isExporting = false

    var body: some View {
        CompatNavigationView {
            Form {
                Section("导出范围") {
                    Picker("范围", selection: $scope) {
                        Text("全书").tag(ExportScope.fullNovel)
                        Text("仅大纲").tag(ExportScope.outlineOnly)
                        if !novel.sortedVolumes.isEmpty {
                            Text("单卷").tag(ExportScope.singleVolume(novel.sortedVolumes.first!.id))
                        }
                    }
                    .pickerStyle(.segmented)

                    if case .singleVolume = scope {
                        Picker("选择卷", selection: $selectedVolumeID) {
                            ForEach(novel.sortedVolumes) { volume in
                                Text(volume.name).tag(Optional(volume.id))
                            }
                        }
                    }
                }

                Section("导出格式") {
                    Picker("格式", selection: $format) {
                        Text("TXT（纯文本）").tag(ExportFormat.txt)
                        Text("Markdown").tag(ExportFormat.markdown)
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("导出作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isExporting ? "生成中…" : "导出并分享") {
                        performExport()
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private func performExport() {
        // 单卷模式：解析目标卷 id，无卷则报错返回
        var scopeToUse = scope
        if case .singleVolume = scope {
            guard let id = selectedVolumeID ?? novel.sortedVolumes.first?.id else {
                errorMessage = "暂无可导出的卷"
                return
            }
            scopeToUse = .singleVolume(id)
        }

        isExporting = true
        defer { isExporting = false }

        let content = ExportService.export(novel: novel, scope: scopeToUse, format: format)
        let name = ExportService.fileName(novel: novel, scope: scopeToUse, format: format)
        if let url = ExportService.writeTemporaryFile(content: content, fileName: name) {
            shareItem = ShareItem(url: url)
        } else {
            errorMessage = "导出失败，请重试"
        }
    }
}

/// 分享面板数据项
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIActivityViewController 的 SwiftUI 包装
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
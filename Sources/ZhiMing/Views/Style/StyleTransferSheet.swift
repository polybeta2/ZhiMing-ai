#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import ZhiMingCore

/// 档案导入导出（P2）：全部档案打包为 JSON 分享出去；从 JSON 文件导入按 id 合并（upsert）。
struct StyleTransferSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        CompatNavigationView {
            Form {
                Section("导出") {
                    Button {
                        exportAll()
                    } label: {
                        Label("导出全部档案（\(store.styleProfiles.count) 份）", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.styleProfiles.isEmpty)
                }
                Section("导入") {
                    Button {
                        showImporter = true
                    } label: {
                        Label("从 JSON 文件导入", systemImage: "square.and.arrow.down")
                    }
                    // 按档案 id 合并：已存在的整份覆盖，其余新增；书级绑定不受影响
                }
                if let message {
                    Section {
                        Label(message, systemImage: messageIsError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundColor(messageIsError ? .red : .green)
                    }
                }
            }
            .navigationTitle("导入 / 导出档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .zmDocumentPicker(isPresented: $showImporter, types: [.json]) { url in
            importJSON(url)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: 导出

    private func exportAll() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store.styleProfiles),
              let json = String(data: data, encoding: .utf8) else {
            setError("档案编码失败")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let stamp = formatter.string(from: .now)
        if let url = ExportService.writeTemporaryFile(content: json, fileName: "zhiming-styles-\(stamp).json") {
            shareItem = ShareItem(url: url)
        } else {
            setError("写入临时文件失败")
        }
    }

    // MARK: 导入

    private func importJSON(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let profiles = try? JSONDecoder().decode([StyleProfile].self, from: data) else {
            setError("文件解析失败：请提供由织命导出的档案 JSON")
            return
        }
        guard !profiles.isEmpty else {
            setError("文件中没有档案")
            return
        }
        let existing = Set(store.styleProfiles.map(\.id))
        var added = 0, updated = 0
        for profile in profiles {
            if existing.contains(profile.id) { updated += 1 } else { added += 1 }
            store.upsertStyleProfile(profile)
        }
        messageIsError = false
        message = "导入完成：新增 \(added) 份，覆盖 \(updated) 份（按档案 id 合并）"
    }

    private func setError(_ text: String) {
        messageIsError = true
        message = text
    }
}

/// 分享面板数据项（与 ExportSheet 同款模式）
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
#endif

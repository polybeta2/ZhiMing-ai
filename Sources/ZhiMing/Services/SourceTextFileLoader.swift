#if os(iOS) || os(macOS)
import Foundation
import CoreFoundation

/// txt 读取统一入口：安全作用域 + UTF-8/UTF-16/GB18030 编码探测 + BOM 剥离
enum SourceTextFileLoader {

    /// 读取结果：success 或带用户可读信息的 failure
    enum LoadOutcome {
        case success(String)
        case failure(String)
    }

    static func loadText(from url: URL) -> LoadOutcome {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            return .failure("无法读取文件（读入失败），请确认文件可访问后重试")
        }
        guard var text = decodeText(data) else {
            return .failure("无法识别文件编码（已尝试 UTF-8 与 GB18030）。请将文件另存为 UTF-8 编码后重试")
        }
        if text.hasPrefix("\u{FEFF}") { text = String(text.dropFirst()) }   // Windows 导出 BOM
        return .success(text)
    }

    /// 编码探测：UTF-8 优先（含 BOM/容错），失败回退 GB18030（覆盖 GBK 全字符集）
    private static func decodeText(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: gb18030)
    }
}
#endif
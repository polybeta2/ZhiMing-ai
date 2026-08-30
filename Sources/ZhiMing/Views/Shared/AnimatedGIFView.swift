#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// GIF 播放控件（SwiftUI 无原生 GIF，用 UIKit `UIImageView.animatedImage` 包装）。
/// 资源读取自 SwiftPM target bundle（Package.swift 已 copy Resources/praying.gif）。
struct AnimatedGIFView: UIViewRepresentable {
    let resourceName: String      // 不带扩展名的资源名

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.animationRepeatCount = 0
        if let animated = Self.loadAnimated(resourceName) {
            view.image = animated
            view.startAnimating()
        } else {
            view.image = UIImage(systemName: "sparkles")
            view.tintColor = .secondaryLabel
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.isAnimating == false, uiView.image?.images != nil {
            uiView.startAnimating()
        }
    }

    /// 用 CGImageSource 读出 GIF 全部帧 → UIImage.animatedImage（重复播放）
    private static func loadAnimated(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif") ??
                        Bundle.module.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var images: [UIImage] = []
        var duration = 0.0
        for i in 0..<count {
            if let cg = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cg))
            }
            // 取帧延迟（gif duration 属性），无则默认 0.1s
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any],
               let delay = gif[kCGImagePropertyGIFDelayTime] as? Double {
                duration += delay
            } else {
                duration += 0.1
            }
        }
        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: duration)
    }
}
#endif
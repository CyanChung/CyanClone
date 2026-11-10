import SwiftUI
import AppKit

// MARK: - 彩蛋字：星漢燦爛

/// 直接用设计给的描线稿（Resources/seal-stars.png）。
/// 图本身是米色线，按 template 用，颜色跟着系统走——深色侧栏下发亮，浅色下转深，
/// 形状一点不损失，也不需要在两套配色里各存一张。
enum SealArt {
    static let stars: NSImage? = {
        guard let url = Bundle.main.url(forResource: "seal-stars", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        return img
    }()

    /// 四字一行的宽高比（约 4.04 : 1）。尺寸都按它算，图片永远等比，不会被压扁。
    static let aspect: CGFloat = {
        guard let img = stars, img.size.height > 0 else { return 4.04 }
        return img.size.width / img.size.height
    }()

    /// 四字一行，按字高铺开
    struct Stars: View {
        var height: CGFloat
        var color: Color = .secondary

        var body: some View {
            if let img = SealArt.stars {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: (height * SealArt.aspect).rounded(), height: height)
                    .fixedSize()
                    .foregroundStyle(color)
                    .accessibilityLabel("星漢燦爛")
            } else {
                SealLine(height: height, color: color)   // 资源缺失时退回矢量版
            }
        }
    }
}

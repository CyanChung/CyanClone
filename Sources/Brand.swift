import SwiftUI
import AppKit

// MARK: - 品牌图形（C + 月亮 / 星芒 / 太阳）

enum BrandVariant: String, CaseIterable, Identifiable {
    case moon
    case star
    case sun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moon: return "月亮"
        case .star: return "星芒"
        case .sun:  return "太阳"
        }
    }

    /// SVG 原稿文件名
    var fileName: String { "\(rawValue).svg" }

    var glyphColor: Color {
        switch self {
        case .moon, .sun: return Color(red: 0.925, green: 0.769, blue: 0.373)
        case .star:       return Color(red: 0.263, green: 0.792, blue: 0.804)
        }
    }

    /// 界面强调色（工具栏图标、菜单、按钮）固定用星芒的青绿。
    /// 不跟侧栏那个小 C 联动——不然点一下彩蛋，右上角就整个换色了。
    static let accent = Color(red: 0.13, green: 0.66, blue: 0.70)
}

enum BrandArt {
    static let navy = Color(red: 0.094, green: 0.196, blue: 0.439)   // #183270
    static let lightBlue = Color(red: 0.623, green: 0.745, blue: 0.973)  // #9fbef8

    /// 直接用设计给的 SVG 原稿，不重画：C 的两层描边、亮面渐变、高光、右上角小元素
    /// 全部照原文件的数值走，改一次资源就是改一次效果，不会出现"看着像但粗细不对"。
    private static var cache: [String: NSImage] = [:]

    static func mark(_ variant: BrandVariant) -> NSImage? {
        if let hit = cache[variant.fileName] { return hit }
        guard let url = Bundle.main.url(forResource: variant.rawValue, withExtension: "svg",
                                        subdirectory: "brand")
                ?? Bundle.main.url(forResource: variant.rawValue, withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return nil }
        // SVG 是矢量的：交给系统按目标尺寸重绘，小尺寸也不会糊
        img.isTemplate = false
        cache[variant.fileName] = img
        return img
    }
}

// MARK: - 在 SwiftUI 里画

struct BrandMark: View {
    var variant: BrandVariant
    /// 侧栏小尺寸：往里收一点点，别贴着边界
    var compact: Bool = false

    var body: some View {
        if let img = BrandArt.mark(variant) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .padding(compact ? 1 : 0)
                .accessibilityLabel("Cyan Clone · \(variant.title)")
        } else {
            BrandMarkFallback(variant: variant)
        }
    }
}

/// 资源缺失时的兜底：按 SVG 的三层结构（藏青底 10 + 亮面 8 + 细高光 2.4）画一遍。
/// 数值与 SVG 一致，所以即使走到这里，粗细也不会跑偏。
private struct BrandMarkFallback: View {
    var variant: BrandVariant

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            var ctx = context
            let scale = size.width / 64
            ctx.scaleBy(x: scale, y: scale)

            let c = BrandMarkFallback.cPath()
            ctx.stroke(c, with: .color(BrandArt.navy),
                       style: StrokeStyle(lineWidth: 10, lineCap: .round))
            ctx.stroke(BrandMarkFallback.lightPath(),
                       with: .linearGradient(
                            Gradient(colors: [.white, BrandArt.lightBlue]),
                            startPoint: CGPoint(x: 10, y: 6),
                            endPoint: CGPoint(x: 48, y: 49)),
                       style: StrokeStyle(lineWidth: 8, lineCap: .round))
            ctx.stroke(BrandMarkFallback.highlightPath(),
                       with: .color(.white.opacity(0.72)),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            switch variant {
            case .star:
                ctx.fill(BrandMarkFallback.starPath(), with: .color(variant.glyphColor))
            case .moon:
                ctx.fill(BrandMarkFallback.moonPath(), with: .color(variant.glyphColor))
            case .sun:
                ctx.fill(Path(ellipseIn: CGRect(x: 46.4, y: 12.4, width: 9.2, height: 9.2)),
                         with: .color(variant.glyphColor))
                ctx.stroke(BrandMarkFallback.sunRays(),
                           with: .color(variant.glyphColor),
                           style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
    }

    private static func cPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 47.5, y: 19))
        p.addCurve(to: CGPoint(x: 13.5, y: 34),
                   control1: CGPoint(x: 34.5, y: 9),
                   control2: CGPoint(x: 13.5, y: 17))
        p.addCurve(to: CGPoint(x: 47.5, y: 49),
                   control1: CGPoint(x: 13.5, y: 51),
                   control2: CGPoint(x: 34.5, y: 59))
        return p
    }

    private static func lightPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 44, y: 15))
        p.addCurve(to: CGPoint(x: 10, y: 32),
                   control1: CGPoint(x: 30.5, y: 5),
                   control2: CGPoint(x: 10, y: 13))
        p.addCurve(to: CGPoint(x: 44, y: 49),
                   control1: CGPoint(x: 10, y: 51),
                   control2: CGPoint(x: 30.5, y: 59))
        return p
    }

    private static func highlightPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 20))
        p.addCurve(to: CGPoint(x: 43, y: 16),
                   control1: CGPoint(x: 27, y: 13),
                   control2: CGPoint(x: 36, y: 12))
        return p
    }

    private static func starPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 8))
        p.addLine(to: CGPoint(x: 52.2, y: 14.1))
        p.addLine(to: CGPoint(x: 58, y: 17))
        p.addLine(to: CGPoint(x: 52.2, y: 19.8))
        p.addLine(to: CGPoint(x: 50, y: 26))
        p.addLine(to: CGPoint(x: 47.8, y: 19.8))
        p.addLine(to: CGPoint(x: 42, y: 17))
        p.addLine(to: CGPoint(x: 47.8, y: 14.1))
        p.closeSubpath()
        return p
    }

    private static func moonPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 53.5, y: 8.49))
        p.addArc(center: CGPoint(x: 53.47, y: 17.5), radius: 9,
                 startAngle: .degrees(-90), endAngle: .degrees(46.2), clockwise: true)
        p.addArc(center: CGPoint(x: 56.6, y: 16.25), radius: 8.3465,
                 startAngle: .degrees(68.2), endAngle: .degrees(248.2), clockwise: false)
        p.closeSubpath()
        return p
    }

    private static func sunRays() -> Path {
        var p = Path()
        let cx: CGFloat = 51, cy: CGFloat = 17
        for (dx, dy) in [(CGFloat(0), CGFloat(-9)), (0, 9), (-9, 0), (9, 0),
                         (-6.4, -6.4), (6.4, 6.4), (6.4, -6.4), (-6.4, 6.4)] {
            let len = sqrt(dx * dx + dy * dy)
            let ux = dx / len, uy = dy / len
            p.move(to: CGPoint(x: cx + ux * 6.4, y: cy + uy * 6.4))
            p.addLine(to: CGPoint(x: cx + ux * 9.0, y: cy + uy * 9.0))
        }
        return p
    }
}

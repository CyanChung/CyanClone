import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 图标缓存：按类型取 Finder 同款图标（文件本体不存在，用扩展名映射）
final class IconProvider {
    static let shared = IconProvider()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    private lazy var folderIcon: NSImage = {
        NSWorkspace.shared.icon(for: .folder)
    }()

    private lazy var documentIcon: NSImage = {
        NSWorkspace.shared.icon(for: .data)
    }()

    func icon(for node: Node) -> NSImage {
        switch node.kind {
        case .folder:
            return folderIcon
        case .symlink:
            return NSWorkspace.shared.icon(for: .symbolicLink)
        case .file:
            let key = node.ext.isEmpty ? "::none" : "ext:" + node.ext
            if let cached = cached(key) { return cached }
            var image = documentIcon
            if !node.ext.isEmpty, let type = UTType(filenameExtension: node.ext) {
                image = NSWorkspace.shared.icon(for: type)
            }
            store(key, image)
            return image
        }
    }

    /// 硬盘图标：挂载着就用真盘图标，否则用通用外置硬盘符号
    func icon(for volume: Volume) -> NSImage? {
        let url = URL(fileURLWithPath: volume.path)
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    func sidebarImage(for volume: Volume) -> NSImage {
        if let real = icon(for: volume) {
            return real
        }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let symbol = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "硬盘")?
            .withSymbolConfiguration(config)
        return symbol ?? folderIcon
    }

    private func cached(_ key: String) -> NSImage? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }

    private func store(_ key: String, _ image: NSImage) {
        lock.lock(); defer { lock.unlock() }
        cache[key] = image
    }
}

// MARK: - 格式化

enum Fmt {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "yyyy/M/d HH:mm"
        return f
    }()

    private static let calendar = Calendar.current

    static func size(_ node: Node) -> String {
        if node.kind == .symlink { return "--" }
        if node.total < 0 { return "--" }        // 没读到，不假装是 0
        if node.total > 0 { return byteFormatter.string(fromByteCount: node.total) }
        return node.isFolder ? "--" : byteFormatter.string(fromByteCount: max(0, node.size))
    }

    static func date(_ node: Node) -> String {
        let d = node.date
        if d.timeIntervalSince1970 <= 0 { return "--" }
        if calendar.isDateInToday(d) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_Hans_CN")
            f.dateFormat = "今天 HH:mm"
            return f.string(from: d)
        }
        if calendar.isDateInYesterday(d) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_Hans_CN")
            f.dateFormat = "昨天 HH:mm"
            return f.string(from: d)
        }
        return dateFormatter.string(from: d)
    }

    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }

    static func count(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - 小三角（Finder 的展开箭头）

struct DisclosureTriangle: View {
    var expanded: Bool
    var color: Color = .secondary

    var body: some View {
        TriangleShape()
            .fill(color)
            .frame(width: 7, height: 8)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .contentShape(Rectangle())
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

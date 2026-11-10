import SwiftUI
import AppKit

// MARK: - 硬盘池

struct PoolView: View {
    @EnvironmentObject var lib: LibraryStore

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 300, maximum: 430), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerRow
                statStrip

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(Array(lib.volumes.enumerated()), id: \.element.id) { index, volume in
                        DriveCard(volume: volume, paletteIndex: index)
                    }
                    AddDriveCard()
                }
            }
            .padding(22)
        }
    }

    // MARK: 顶部：最后同步 + 全部同步

    private var headerRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("最后同步")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(lib.lastSyncText)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()

            if let scan = lib.scanState {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 6)
                Text("正在同步「\(scan.name)」· \(Fmt.count(scan.scanned)) 项")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            Button {
                lib.syncAll()
            } label: {
                Label("全部同步", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .disabled(lib.scanState != nil)
            .help("按每块盘各自的范围与深度重新扫描（只读，不会改动盘上任何东西）")
        }
    }

    private var statStrip: some View {
        let count = lib.volumes.count
        let deviceCount = lib.volumes.filter { $0.isDevice }.count
        let capacity = lib.volumes.reduce(Int64(0)) { $0 + $1.capacity }
        let indexed = lib.volumes.reduce(Int64(0)) { $0 + $1.totalBytes }
        let items = lib.volumes.reduce(0) { $0 + $1.itemCount }

        return HStack(spacing: 10) {
            statTile("硬盘",
                     deviceCount == count ? "\(count) 块" : "\(deviceCount) 块 + \(count - deviceCount) 个文件夹",
                     "externaldrive.fill")
            statTile("总容量", capacity > 0 ? Fmt.bytes(capacity) : "—", "internaldrive")
            statTile("已索引", Fmt.bytes(indexed), "square.stack.3d.up")
            statTile("项目", Fmt.count(items), "doc.on.doc")
        }
    }

    private func statTile(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        )
    }
}

// MARK: - 气泡数据

private struct BubbleItem: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int64
    let node: Node?
    var symbol: String { node?.isFolder == false ? "doc.fill" : "folder.fill" }
}

// MARK: - 单块硬盘卡片

struct DriveCard: View {
    let volume: Volume
    let paletteIndex: Int

    @EnvironmentObject var lib: LibraryStore
    @State private var hovering = false
    @State private var hoveringSync = false
    @State private var hoveringRename = false

    private var palette: [Color] { DrivePalette.colors(paletteIndex) }
    private var isMounted: Bool { lib.isMounted(volume) }
    private var isScanning: Bool { lib.isScanning(volume) }

    private var bubbleItems: [BubbleItem] {
        let kids = (volume.root.children ?? []).filter { $0.total > 0 }
        let sorted = kids.sorted { $0.total > $1.total }
        var items = sorted.prefix(6).map { BubbleItem(name: $0.name, bytes: $0.total, node: $0) }
        if sorted.count > 6 {
            let restBytes = sorted.dropFirst(6).reduce(Int64(0)) { $0 + $1.total }
            if restBytes > 0 {
                items.append(BubbleItem(name: "其他", bytes: restBytes, node: nil))
            }
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            sizeBlock
            bubbleArea
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(hovering ? 0.22 : 0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(hovering ? 0.32 : 0.20),
                radius: hovering ? 16 : 9,
                y: hovering ? 7 : 4)
        .scaleEffect(hovering ? 1.005 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture { lib.openVolume(volume) }
        .contextMenu { contextMenu }
        .help(cardHelp)
    }

    private var cardHelp: String {
        var lines: [String] = ["点开浏览「\(volume.displayName)」"]
        if volume.hasCustomName { lines.append("原名：\(volume.name)") }
        if !volume.deviceSummary.isEmpty { lines.append(volume.deviceSummary) }
        if !volume.deviceSerial.isEmpty { lines.append("序列号：\(volume.deviceSerial)") }
        if !volume.path.isEmpty { lines.append(volume.path) }
        return lines.joined(separator: "\n")
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.14), .clear],
                           center: .topLeading, startRadius: 4,
                           endRadius: 320)
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(nsImage: IconProvider.shared.sidebarImage(for: volume))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 19, height: 19)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.displayName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(subline)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            scopeBadge
                .padding(.top, 2)

            HStack(spacing: 4) {
                Button {
                    lib.promptRename(volume)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(hoveringRename ? 0.24 : 0.12)))
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0.55)
                .onHover { hoveringRename = $0 }
                .help("重命名显示名称（不会改动硬盘）")

                syncMenu
            }
            .padding(.top, 1)
        }
    }

    /// 名字下面这行：整盘显示型号，文件夹显示所在盘
    private var subline: String {
        if volume.isDevice {
            return volume.deviceSummary.isEmpty ? "型号未识别" : volume.deviceSummary
        }
        return volume.hostVolume.isEmpty ? "文件夹索引" : "所在盘 \(volume.hostVolume)"
    }

    /// 整盘 / 文件夹 的标识
    private var scopeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: volume.isDevice ? "externaldrive.fill" : "folder.fill")
                .font(.system(size: 8))
            Text(volume.scope.title)
                .font(.system(size: 9.5, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.15)))
        .help(volume.isDevice ? "整块硬盘：\(volume.path)" : "硬盘里的文件夹：\(volume.path)")
    }

    /// 同步按钮：默认沿用上次的范围，菜单里可以改范围
    private var syncMenu: some View {
        Menu {
            Button {
                lib.rescan(volume)
            } label: {
                Label("同步（沿用范围：\(volume.depthText)）", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            // 深度不再放在二级菜单里逐级点：菜单只负责打开小面板，
            // 选层级、确认高层级都在面板里做（菜单动作里不弹模态、不改数据）
            Button("更改索引深度…（现在 \(volume.depthText)）") {
                lib.promptScanDepth(for: volume)
            }

            if volume.isDevice {
                Button("改为扫描盘内文件夹…") {
                    pickFolder(startAt: URL(fileURLWithPath: volume.path), depth: volume.maxDepth)
                }
            } else {
                if let host = hostVolumeURL {
                    Button("扩大到整块硬盘") {
                        lib.rescan(volume, depth: volume.maxDepth, at: host)
                    }
                }
                Button("更换扫描位置…") {
                    pickFolder(startAt: URL(fileURLWithPath: volume.path), depth: volume.maxDepth)
                }
            }

            Divider()

            Button("在 Finder 中显示") {
                NSWorkspace.shared.open(URL(fileURLWithPath: volume.path))
            }
            Button("移除索引", role: .destructive) { lib.removeVolume(volume) }
        } label: {
            ZStack {
                Circle().fill(Color.white.opacity(hoveringSync ? 0.24 : 0.12))
                if isScanning {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hoveringSync = $0 }
        .help("同步这块盘的索引（只读，不会改动盘上的文件）")
    }

    private var hostVolumeURL: URL? {
        try? URL(fileURLWithPath: volume.path).resourceValues(forKeys: [.volumeURLKey]).volume
    }

    private func pickFolder(startAt: URL?, depth: Int) {
        let panel = NSOpenPanel()
        panel.title = "选择要索引的文件夹"
        panel.message = "会用这个位置替换「\(volume.name)」的索引，深度 \(depth) 级。"
        panel.prompt = "开始扫描"
        panel.directoryURL = startAt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            lib.rescan(volume, depth: depth, at: url)
        }
    }

    // MARK: 大小

    private var sizeBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.bytes(volume.totalBytes))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("已索引")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if volume.isDevice {
                Text(deviceLine)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                capacityBar
                    .padding(.top, 2)
            } else {
                Text("范围 \(volume.path)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(volume.path)

                Text("不统计整盘容量")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .padding(.top, 12)
    }

    private var deviceLine: String {
        guard let cap = volume.capacityText else {
            return "容量未知 · 索引 \(volume.maxDepth) 级"
        }
        return "共 \(cap) · 磁盘已用 \(Fmt.bytes(volume.usedBytes))（\(usagePercent)%）"
    }

    private var usagePercent: Int {
        guard volume.capacity > 0 else { return 0 }
        return Int((Double(volume.usedBytes) / Double(volume.capacity) * 100).rounded())
    }

    private var capacityBar: some View {
        GeometryReader { geo in
            let ratio: CGFloat = {
                guard volume.capacity > 0 else { return 0 }
                return min(1, CGFloat(Double(volume.usedBytes) / Double(volume.capacity)))
            }()
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.28))
                if ratio > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.55)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, geo.size.width * ratio))
                }
            }
        }
        .frame(height: 4)
    }

    // MARK: 气泡

    private var bubbleArea: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Circle()
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: side * 0.96, height: side * 0.96)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)

            let placed = CirclePacker.pack(bubbleItems.map { $0.bytes }, in: geo.size)
            ForEach(placed) { spot in
                bubble(bubbleItems[spot.index], radius: spot.radius)
                    .position(spot.center)
            }
        }
        .frame(height: 150)
        .padding(.top, 12)
    }

    private func bubble(_ item: BubbleItem, radius: CGFloat) -> some View {
        let showName = radius >= 24
        let showSize = radius >= 36
        return Button {
            guard let node = item.node else { return }
            lib.openVolume(volume, at: node)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.09)],
                                       center: .topLeading, startRadius: 2, endRadius: radius * 2)
                    )
                Circle()
                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)

                if showName {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol)
                            .font(.system(size: min(14, radius * 0.36)))
                            .foregroundStyle(.white.opacity(0.88))

                        Text(item.name)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.96))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .frame(width: radius * 1.52)

                        if showSize {
                            Text(Fmt.bytes(item.bytes))
                                .font(.system(size: 8.5))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(width: radius * 1.55)
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: max(7, radius * 0.55)))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: radius * 2, height: radius * 2)
        }
        .buttonStyle(.plain)
        .help("\(item.name)\n\(Fmt.bytes(item.bytes))")
    }

    // MARK: 底部

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isMounted ? Color(red: 0.42, green: 0.86, blue: 0.62) : Color.white.opacity(0.45))
                .frame(width: 5, height: 5)

            Text(footerText)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .monospacedDigit()

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Text("浏览")
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(hovering ? 0.95 : 0.6))
        }
        .padding(.top, 10)
    }

    private var footerText: String {
        if let scan = lib.scanState, scan.volumeID == volume.id {
            return "同步中… \(Fmt.count(scan.scanned)) 项"
        }
        let mount = isMounted ? "已挂载" : "未挂载"
        return "\(mount) · \(Fmt.count(volume.itemCount)) 项 · 索引 \(volume.depthText) · \(volume.scannedText)"
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("浏览") { lib.openVolume(volume) }
        Button("重命名显示名称…") { lib.promptRename(volume) }
        if volume.hasCustomName {
            Button("恢复原名「\(volume.name)」") { lib.renameVolume(volume, to: "") }
        }
        Button("同步（沿用范围：\(volume.depthText)）") { lib.rescan(volume) }
        // 和卡片右上角菜单、侧栏右键一致：菜单只打开面板，
        // 不在菜单动作里改数据 / 弹模态（二级 Menu + NSAlert 是之前闪退的入口）
        Button("更改索引深度…（现在 \(volume.depthText)）") {
            lib.promptScanDepth(for: volume)
        }
        Divider()
        Button("在 Finder 中显示") {
            NSWorkspace.shared.open(URL(fileURLWithPath: volume.path))
        }
        Button("移除索引", role: .destructive) { lib.removeVolume(volume) }
    }
}

// MARK: - 添加硬盘占位卡

struct AddDriveCard: View {
    @EnvironmentObject var lib: LibraryStore
    @State private var hovering = false

    var body: some View {
        Button {
            lib.chooseVolumesToScan()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 26, weight: .light))
                Text("添加硬盘")
                    .font(.system(size: 13, weight: .medium))
                Text("默认扫描 \(lib.defaultDepth) 级目录")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.055 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                    .foregroundStyle(Color.primary.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 配色

enum DrivePalette {
    /// 深色模式下好看的几组低饱和渐变
    static let pairs: [[Color]] = [
        [Color(red: 0.11, green: 0.38, blue: 0.38), Color(red: 0.06, green: 0.22, blue: 0.26)],
        [Color(red: 0.16, green: 0.26, blue: 0.46), Color(red: 0.08, green: 0.14, blue: 0.30)],
        [Color(red: 0.30, green: 0.20, blue: 0.40), Color(red: 0.16, green: 0.10, blue: 0.26)],
        [Color(red: 0.38, green: 0.27, blue: 0.13), Color(red: 0.22, green: 0.15, blue: 0.08)],
        [Color(red: 0.12, green: 0.34, blue: 0.25), Color(red: 0.06, green: 0.20, blue: 0.16)],
        [Color(red: 0.36, green: 0.16, blue: 0.22), Color(red: 0.20, green: 0.08, blue: 0.14)],
    ]

    static func colors(_ index: Int) -> [Color] {
        pairs[abs(index) % pairs.count]
    }
}

// MARK: - 圆形装箱

enum CirclePacker {
    struct Spot: Identifiable {
        let index: Int
        let center: CGPoint
        let radius: CGFloat
        var id: Int { index }
    }

    /// 按字节数算面积装箱；放不下就整体缩小半径重试，保证不会只剩一个圆
    static func pack(_ bytes: [Int64], in size: CGSize) -> [Spot] {
        guard !bytes.isEmpty, size.width > 40, size.height > 40 else { return [] }
        let total = max(bytes.reduce(0, +), 1)
        let targetArea = size.width * size.height * 0.54
        let areaPerByte = targetArea / Double(total)
        let maxRadius = min(size.width, size.height) * 0.44

        let baseRadii = bytes.map { value -> CGFloat in
            let raw = CGFloat(sqrt(Double(max(value, 1)) * areaPerByte / .pi))
            return min(max(raw, 11), maxRadius)
        }
        // 需要显示的气泡（太小的直接不画，免得变成莫名其妙的小点）
        let wantedIndices = Set(baseRadii.enumerated().filter { $0.element >= 15 }.map { $0.offset })
        guard !wantedIndices.isEmpty else { return [] }

        let scales: [CGFloat] = [1, 0.94, 0.88, 0.82, 0.76, 0.70, 0.64, 0.58, 0.52, 0.46, 0.40, 0.34, 0.28]
        var best: [Spot] = []
        var bestScore = -1

        for scale in scales {
            let radii = baseRadii.map { $0 * scale }
            let placed = attempt(radii: radii, in: size)
            let placedIndices = Set(placed.map { $0.index })
            let score = wantedIndices.intersection(placedIndices).count
            if score > bestScore {
                bestScore = score
                best = placed
            }
            if wantedIndices.isSubset(of: placedIndices) { return placed }
        }
        return best
    }

    private static func attempt(radii: [CGFloat], in size: CGSize) -> [Spot] {
        var placements: [Spot] = []
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for (index, radius) in radii.enumerated() {
            if radius < 15 { continue }
            if placements.isEmpty {
                placements.append(Spot(index: index, center: center, radius: radius))
                continue
            }
            var found: CGPoint?
            var angle: CGFloat = 0
            var distance: CGFloat = radius + 2
            var guardCount = 0

            while found == nil && guardCount < 5000 {
                guardCount += 1
                angle += 0.3
                if angle > .pi * 2 {
                    angle -= .pi * 2
                    distance += 3
                }
                let point = CGPoint(x: center.x + cos(angle) * distance,
                                    y: center.y + sin(angle) * distance)
                if point.x - radius < 0 || point.x + radius > size.width { continue }
                if point.y - radius < 0 || point.y + radius > size.height { continue }

                var collides = false
                for other in placements {
                    let dx = point.x - other.center.x
                    let dy = point.y - other.center.y
                    if sqrt(dx * dx + dy * dy) < radius + other.radius + 2 {
                        collides = true
                        break
                    }
                }
                if !collides { found = point }
            }
            if let point = found {
                placements.append(Spot(index: index, center: point, radius: radius))
            }
        }
        return placements
    }
}

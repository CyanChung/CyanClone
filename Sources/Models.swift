import Foundation

// MARK: - 节点类型

enum NodeKind: String, Codable {
    case folder
    case file
    case symlink
}

// MARK: - 目录节点

final class Node: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: NodeKind
    var size: Int64            // 自身大小（文件才有）
    var total: Int64           // 子树总大小：扫描时累加出来的真实字节数
    var partial: Bool          // 子树里还有没展开的部分，total 只是下限
    var mtime: TimeInterval    // 1970 起算
    var ext: String            // 小写扩展名
    var truncated: Bool        // 已达到索引深度 / 无权限，未展开子项
    var children: [Node]?
    weak var parent: Node?

    /// 没读到大小（连 stat 都失败）时用它，显示为 "--"，避免误报成 0
    static let unknownSize: Int64 = -1

    init(name: String,
         kind: NodeKind,
         size: Int64 = 0,
         total: Int64 = 0,
         partial: Bool = false,
         mtime: TimeInterval = 0,
         ext: String = "",
         truncated: Bool = false,
         children: [Node]? = nil) {
        self.id = UUID()
        self.name = name
        self.kind = kind
        self.size = size
        self.total = total
        self.partial = partial
        self.mtime = mtime
        self.ext = ext
        self.truncated = truncated
        self.children = children
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, size, total, partial, mtime, ext, truncated, children
    }

    // 兼容旧索引：缺字段时给默认值
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(NodeKind.self, forKey: .kind)
        size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        total = try c.decodeIfPresent(Int64.self, forKey: .total) ?? size
        partial = try c.decodeIfPresent(Bool.self, forKey: .partial) ?? false
        mtime = try c.decodeIfPresent(TimeInterval.self, forKey: .mtime) ?? 0
        ext = try c.decodeIfPresent(String.self, forKey: .ext) ?? ""
        truncated = try c.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
        children = try c.decodeIfPresent([Node].self, forKey: .children)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
        try c.encode(size, forKey: .size)
        try c.encode(total, forKey: .total)
        try c.encode(partial, forKey: .partial)
        try c.encode(mtime, forKey: .mtime)
        try c.encode(ext, forKey: .ext)
        try c.encode(truncated, forKey: .truncated)
        try c.encodeIfPresent(children, forKey: .children)
    }

    var isFolder: Bool { kind == .folder }
    var isHiddenName: Bool { name.hasPrefix(".") }
    var childCount: Int { children?.count ?? 0 }
    var date: Date { Date(timeIntervalSince1970: mtime) }

    var kindName: String { KindName.describe(node: self) }

    static func == (lhs: Node, rhs: Node) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// 重建父指针（解码之后必须调用）
    func linkParents() {
        guard let children else { return }
        for child in children {
            child.parent = self
            child.linkParents()
        }
    }

    func itemCount() -> Int {
        var n = 0
        guard let children else { return 0 }
        for c in children {
            n += 1
            if c.isFolder { n += c.itemCount() }
        }
        return n
    }

    /// 旧索引没有子树大小，用已记录的文件大小重新累加
    @discardableResult
    func recomputeTotals() -> (Int64, Bool) {
        switch kind {
        case .file:
            total = size
            return (size, false)
        case .symlink:
            total = 0
            return (0, false)
        case .folder:
            var sum: Int64 = 0
            var incomplete = truncated
            for child in children ?? [] {
                let (childTotal, childIncomplete) = child.recomputeTotals()
                sum += childTotal
                incomplete = incomplete || childIncomplete
            }
            total = sum
            partial = incomplete
            return (sum, incomplete)
        }
    }

    /// 从自己往上数到硬盘根（不含根），用于拼路径
    func chainToRoot() -> [Node] {
        var nodes: [Node] = []
        var cur: Node? = self
        while let c = cur, c.parent != nil {
            nodes.insert(c, at: 0)
            cur = c.parent
        }
        return nodes
    }

    // MARK: 排序

    static func nameIsOrdered(_ a: Node, _ b: Node) -> Bool {
        let r = a.name.compare(b.name,
                              options: [.caseInsensitive, .numeric, .widthInsensitive, .forcedOrdering],
                              locale: Locale(identifier: "zh_Hans_CN"))
        if r == .orderedSame { return a.name < b.name }
        return r == .orderedAscending
    }

    static func compare(_ a: Node, _ b: Node, key: SortKey, ascending: Bool) -> Bool {
        var result: Bool
        switch key {
        case .name:
            result = nameIsOrdered(a, b)
        case .date:
            if a.mtime == b.mtime { result = nameIsOrdered(a, b) }
            else { result = a.mtime < b.mtime }
        case .size:
            if a.total == b.total { result = nameIsOrdered(a, b) }
            else { result = a.total < b.total }
        case .kind:
            let ka = a.isFolder ? "0" : a.ext
            let kb = b.isFolder ? "0" : b.ext
            if ka == kb { result = nameIsOrdered(a, b) }
            else { result = ka < kb }
        }
        return ascending ? result : !result
    }

    func sortRecursively(key: SortKey, ascending: Bool) {
        guard let children else { return }
        for child in children { child.sortRecursively(key: key, ascending: ascending) }
        self.children = children.sorted { Node.compare($0, $1, key: key, ascending: ascending) }
    }
}

enum SortKey: String, CaseIterable, Identifiable {
    case name, date, size, kind
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "名称"
        case .date: return "修改日期"
        case .size: return "大小"
        case .kind: return "种类"
        }
    }
}

enum ViewMode: String, CaseIterable, Identifiable {
    case list, column, icon
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .list: return "list.bullet"
        case .column: return "rectangle.split.3x1"
        case .icon: return "square.grid.2x2"
        }
    }
    var title: String {
        switch self {
        case .list: return "列表"
        case .column: return "分栏"
        case .icon: return "图标"
        }
    }
}

/// 索引的范围：整块硬盘，还是盘里的某个文件夹
enum ScanScope: String, Codable {
    case device
    case folder

    var title: String {
        switch self {
        case .device: return "整盘"
        case .folder: return "文件夹"
        }
    }
}

/// 当前在哪个页面
enum Screen: String {
    case pool
    case browser
}

// MARK: - 硬盘档案

struct Volume: Identifiable, Codable {
    var id = UUID()
    var name: String
    var path: String
    var scannedAt: Date
    var maxDepth: Int
    var fileCount: Int
    var folderCount: Int
    var totalBytes: Int64       // 索引到的字节总和
    var capacity: Int64 = 0     // 扫描时读到的卷容量（0 = 未知；文件夹范围不记）
    var freeSpace: Int64 = 0    // 扫描时读到的剩余空间
    var scope: ScanScope = .device
    var hostVolume: String = ""  // 文件夹范围时，所在的卷名
    // 硬件信息（扫描时探测，拔盘后仍保留）
    var deviceModel: String = ""
    var deviceBus: String = ""
    var deviceLocation: String = ""
    var deviceMedium: String = ""
    var deviceSerial: String = ""
    var fileSystem: String = ""
    /// 用户自定义的显示名称（只影响 App 内显示）
    var customName: String = ""
    var root: Node

    var itemCount: Int { fileCount + folderCount }

    var scannedText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: scannedAt)
    }

    var usedBytes: Int64 {
        guard capacity > 0 else { return 0 }
        return max(0, capacity - freeSpace)
    }

    var capacityText: String? { capacity > 0 ? Fmt.bytes(capacity) : nil }

    var depthText: String { "\(maxDepth) 级" }

    var isDevice: Bool { scope == .device }

    /// 界面上一律用这个（自定义名优先）
    var displayName: String {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }

    var hasCustomName: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isVirtualDevice: Bool {
        deviceBus == "Virtual Interface" || deviceModel == "Apple Disk Image"
    }

    /// 型号 · 总线 · 文件系统
    var deviceSummary: String {
        if isVirtualDevice {
            return fileSystem.isEmpty ? "磁盘映像" : "磁盘映像 · \(fileSystem)"
        }
        var parts: [String] = []
        if !deviceModel.isEmpty { parts.append(deviceModel) }
        let busLabel = DriveInfo.busLabel(deviceBus, isVirtual: false)
        if !busLabel.isEmpty { parts.append(busLabel) }
        if !fileSystem.isEmpty { parts.append(fileSystem) }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    /// 卡片副标题：整盘说容量，文件夹说位置
    var scopeText: String {
        switch scope {
        case .device:
            return capacity > 0 ? "共 \(Fmt.bytes(capacity))" : "容量未知"
        case .folder:
            return hostVolume.isEmpty ? path : "位于 \(hostVolume)"
        }
    }
}

extension Volume {
    enum Keys: String, CodingKey {
        case id, name, path, scannedAt, maxDepth, fileCount, folderCount, totalBytes, capacity, freeSpace, scope, hostVolume,
             deviceModel, deviceBus, deviceLocation, deviceMedium, deviceSerial, fileSystem, customName, root
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        scannedAt = try c.decode(Date.self, forKey: .scannedAt)
        maxDepth = try c.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 3
        fileCount = try c.decodeIfPresent(Int.self, forKey: .fileCount) ?? 0
        folderCount = try c.decodeIfPresent(Int.self, forKey: .folderCount) ?? 0
        totalBytes = try c.decodeIfPresent(Int64.self, forKey: .totalBytes) ?? 0
        capacity = try c.decodeIfPresent(Int64.self, forKey: .capacity) ?? 0
        freeSpace = try c.decodeIfPresent(Int64.self, forKey: .freeSpace) ?? 0
        scope = try c.decodeIfPresent(ScanScope.self, forKey: .scope) ?? .device
        hostVolume = try c.decodeIfPresent(String.self, forKey: .hostVolume) ?? ""
        deviceModel = try c.decodeIfPresent(String.self, forKey: .deviceModel) ?? ""
        deviceBus = try c.decodeIfPresent(String.self, forKey: .deviceBus) ?? ""
        deviceLocation = try c.decodeIfPresent(String.self, forKey: .deviceLocation) ?? ""
        deviceMedium = try c.decodeIfPresent(String.self, forKey: .deviceMedium) ?? ""
        deviceSerial = try c.decodeIfPresent(String.self, forKey: .deviceSerial) ?? ""
        fileSystem = try c.decodeIfPresent(String.self, forKey: .fileSystem) ?? ""
        customName = try c.decodeIfPresent(String.self, forKey: .customName) ?? ""
        root = try c.decode(Node.self, forKey: .root)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(path, forKey: .path)
        try c.encode(scannedAt, forKey: .scannedAt)
        try c.encode(maxDepth, forKey: .maxDepth)
        try c.encode(fileCount, forKey: .fileCount)
        try c.encode(folderCount, forKey: .folderCount)
        try c.encode(totalBytes, forKey: .totalBytes)
        try c.encode(capacity, forKey: .capacity)
        try c.encode(freeSpace, forKey: .freeSpace)
        try c.encode(scope, forKey: .scope)
        try c.encode(hostVolume, forKey: .hostVolume)
        try c.encode(deviceModel, forKey: .deviceModel)
        try c.encode(deviceBus, forKey: .deviceBus)
        try c.encode(deviceLocation, forKey: .deviceLocation)
        try c.encode(deviceMedium, forKey: .deviceMedium)
        try c.encode(deviceSerial, forKey: .deviceSerial)
        try c.encode(fileSystem, forKey: .fileSystem)
        try c.encode(customName, forKey: .customName)
        try c.encode(root, forKey: .root)
    }
}

struct LibraryFile: Codable {
    var version: Int = 2
    var volumes: [Volume] = []
}

import Foundation

/// 深度受限的目录扫描器：**只读元数据**，从不打开、复制、修改、删除任何文件。
enum Scanner {

    /// 允许的索引深度范围
    static let minDepth = 1
    static let maxDepthLimit = 8

    /// 单次扫描最多收录的条目数（安全阀）。120 万约合 ~210 MB 索引、~250 MB 内存，
    /// 足够覆盖大多数素材盘，又不至于让启动加载和搜索明显变慢。
    static let maxNodes = 1_200_000

    /// 系统噪声目录，Finder 里也基本看不到，直接跳过
    static let skipNames: Set<String> = [
        ".Spotlight-V100", ".Trashes", ".fseventsd", ".TemporaryItems",
        ".DocumentRevisions-V100", ".com.apple.timemachine.donotpresent",
        ".vol", ".PKInstallSandboxManager", "System Volume Information",
        "$RECYCLE.BIN", ".ds_store"
    ]

    static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey,
        .fileSizeKey, .totalFileSizeKey, .totalFileAllocatedSizeKey,
        .contentModificationDateKey, .nameKey
    ]

    static let volumeKeys: Set<URLResourceKey> = [
        .volumeURLKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeNameKey
    ]

    struct Result {
        var root: Node
        var fileCount: Int
        var folderCount: Int
        var totalBytes: Int64
        var capacity: Int64
        var freeSpace: Int64
        var scope: ScanScope
        var hostVolume: String
        var hitLimit: Bool
        var device: DriveInfo.Snapshot
    }

    private final class Ctx {
        var files = 0
        var folders = 0
        var bytes: Int64 = 0
        var tick = 0
        var nodes = 0
        var hitLimit = false

        /// 返回 false 表示已到收录上限
        func canAdd() -> Bool {
            if nodes >= maxNodes {
                hitLimit = true
                return false
            }
            nodes += 1
            return true
        }
    }

    /// - Parameters:
    ///   - url: 硬盘根或盘里某个文件夹
    ///   - depth: 索引层数，3 表示：根 → 一级 → 二级 → 三级（三级文件夹不再展开）
    ///   - progress: 每扫描约 400 个条目回调一次（累计数量）
    static func scanVolume(at url: URL,
                           depth: Int = 3,
                           progress: @escaping (Int) -> Void = { _ in }) -> Result {
        let levels = min(max(depth, minDepth), maxDepthLimit)
        let ctx = Ctx()

        let stdURL = url.standardizedFileURL
        let volValues = try? stdURL.resourceValues(forKeys: volumeKeys)
        let volumeURL = volValues?.volume?.standardizedFileURL
        let isRoot: Bool = {
            if let volumeURL { return volumeURL.path == stdURL.path }
            // 兜底：直接挂在 /Volumes 下
            let parent = (stdURL.path as NSString).deletingLastPathComponent
            return parent == "/Volumes" || stdURL.path == "/"
        }()

        let capacity = isRoot ? Int64(volValues?.volumeTotalCapacity ?? 0) : 0
        let free = isRoot ? Int64(volValues?.volumeAvailableCapacity ?? 0) : 0
        let hostName = volValues?.volumeName ?? ""
        let device = DriveInfo.probe(path: stdURL.path)

        let root = makeNode(url: stdURL,
                            depth: 0,
                            maxDepth: levels,
                            ctx: ctx,
                            progress: progress)
        return Result(root: root,
                      fileCount: ctx.files,
                      folderCount: ctx.folders,
                      totalBytes: ctx.bytes,
                      capacity: capacity,
                      freeSpace: free,
                      scope: isRoot ? .device : .folder,
                      hostVolume: hostName,
                      hitLimit: ctx.hitLimit,
                      device: device)
    }

    // MARK: - 单个条目

    private static func makeNode(url: URL,
                                 depth: Int,
                                 maxDepth: Int,
                                 ctx: Ctx,
                                 progress: @escaping (Int) -> Void) -> Node {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: resourceKeys)

        var isDir = values?.isDirectory ?? false
        var isLink = values?.isSymbolicLink ?? false
        var isPackage = values?.isPackage ?? false
        var mtime = (values?.contentModificationDate ?? Date()).timeIntervalSince1970

        // URL 资源值读不到时退回 stat（异常权限、部分网络卷）
        if values == nil, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
            isLink = (attrs[.type] as? FileAttributeType) == .typeSymbolicLink
            if let modified = attrs[.modificationDate] as? Date {
                mtime = modified.timeIntervalSince1970
            }
        }

        // 符号链接：只记名字，不跟随（避免循环和越界）
        if isLink {
            return Node(name: name, kind: .symlink, mtime: mtime, ext: ext)
        }

        // 包（.app / .fcpbundle / .photoslibrary …）：Finder 里当作一个文件，
        // 但目录自身大小是 0 或 96 字节，必须递归累加真实大小，否则会显示 0 B。
        if isDir && isPackage {
            let bytes = packageSize(url)
            ctx.files += 1
            ctx.bytes += bytes
            return Node(name: name, kind: .file, size: bytes, total: bytes, mtime: mtime, ext: ext)
        }

        if !isDir {
            // 扫描那一刻读到的真实字节数
            var sizeValue: Int?
            if let values {
                sizeValue = values.fileSize ?? values.totalFileSize ?? values.totalFileAllocatedSize
            }
            var bytes = sizeValue.map(Int64.init) ?? Node.unknownSize
            // fileSize 报 0 时再核对一次 stat，避免把非空文件写成 0
            if bytes == 0, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let statSize = (attrs[.size] as? NSNumber)?.int64Value, statSize > 0 {
                bytes = statSize
            }
            ctx.files += 1
            if bytes > 0 { ctx.bytes += bytes }
            return Node(name: name, kind: .file, size: bytes, total: bytes, mtime: mtime, ext: ext)
        }

        // 普通文件夹
        if depth > 0 { ctx.folders += 1 }
        let node = Node(name: name, kind: .folder, mtime: mtime, ext: ext)

        guard depth < maxDepth else {
            node.truncated = true
            node.partial = true
            return node
        }
        guard ctx.canAdd() else {
            node.truncated = true
            node.partial = true
            return node
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ) else {
            node.truncated = true       // 无权限 / 读失败
            node.partial = true
            return node
        }

        var children: [Node] = []
        children.reserveCapacity(entries.count)
        var sum: Int64 = 0
        var partial = false

        for entry in entries {
            let n = entry.lastPathComponent
            if skipNames.contains(n) { continue }
            if ctx.nodes >= maxNodes {
                ctx.hitLimit = true
                node.truncated = true
                partial = true
                break
            }
            let child = makeNode(url: entry,
                                 depth: depth + 1,
                                 maxDepth: maxDepth,
                                 ctx: ctx,
                                 progress: progress)
            if child.total > 0 { sum += child.total }
            if child.truncated || child.partial || child.total < 0 { partial = true }
            children.append(child)
            ctx.tick += 1
            if ctx.tick % 400 == 0 {
                progress(ctx.files + ctx.folders)
            }
        }
        children.sort(by: Node.nameIsOrdered)
        node.children = children
        node.total = sum
        node.partial = partial
        return node
    }

    // MARK: - 包的大小

    /// 递归统计包内部真实字节数；只读元数据，不打开文件内容
    private static func packageSize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }      // 遇到读不了的子项就跳过
        ) else { return 0 }

        var guardCount = 0
        for case let item as URL in enumerator {
            guardCount += 1
            if guardCount > 200_000 { break }    // 极端情况下收手
            if let v = try? item.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               v.isRegularFile == true {
                total += Int64(v.fileSize ?? 0)
            }
        }
        return total
    }
}

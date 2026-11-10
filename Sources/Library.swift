import Foundation
import AppKit
import SwiftUI

/// 索引库：多块硬盘的目录结构，持久化在 ~/Library/Application Support/DriveShell/index.json
@MainActor
final class LibraryStore: ObservableObject {

    @Published private(set) var volumes: [Volume] = []
    @Published var selectedVolumeID: Volume.ID?
    @Published var path: [Node] = []              // 从一级目录到当前目录
    @Published var selectedNodeID: Node.ID?
    @Published var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "ViewMode") ?? "") ?? .column {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "ViewMode") }
    }
    @Published var sortKey: SortKey = .name
    @Published var sortAscending: Bool = true
    @Published var showHidden: Bool = false
    @Published var searchText: String = "" {
        didSet {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchScopeOverride = nil
            }
        }
    }
    @Published var inspectorVisible: Bool = true
    @Published var scanState: ScanState?
    @Published var errorMessage: String?
    @Published var refreshToken: Int = 0

    /// 页面：硬盘池 / 浏览（记住上次停在哪）
    @Published var screen: Screen = Screen(rawValue: UserDefaults.standard.string(forKey: "Screen") ?? "") ?? .pool {
        didSet { UserDefaults.standard.set(screen.rawValue, forKey: "Screen") }
    }

    /// 新扫描默认深度（1…8），默认 3
    @Published var defaultDepth: Int = {
        let saved = UserDefaults.standard.integer(forKey: "DefaultDepth")
        return saved >= 1 && saved <= 8 ? saved : 3
    }() {
        didSet {
            defaultDepth = min(max(defaultDepth, 1), 8)
            UserDefaults.standard.set(defaultDepth, forKey: "DefaultDepth")
        }
    }

    /// 侧栏顶部的品牌标记（月亮 / 星芒 / 太阳）
    @Published var brandVariant: BrandVariant = BrandVariant(rawValue: UserDefaults.standard.string(forKey: "BrandVariant") ?? "") ?? .star {
        didSet { UserDefaults.standard.set(brandVariant.rawValue, forKey: "BrandVariant") }
    }

    func setBrandVariant(_ variant: BrandVariant) {
        guard variant != brandVariant else { return }
        brandVariant = variant
        // App 图标固定用设计给的那张（AppIcon.icns），不再跟随侧栏标记变化
    }

    /// 分栏视图里当前选中的链路（每栏一个选中项）
    @Published var columnChain: [Node] = []

    enum SearchScope {
        case current
        case all
    }

    /// nil = 跟随当前页面（硬盘池搜全部，进了某块盘只搜这块）
    @Published var searchScopeOverride: SearchScope?

    private var forwardStack: [Node] = []
    private var didLoad = false
    private var inspectorBeforePool = true

    private struct ScanJob {
        let url: URL
        let depth: Int
        let existingID: Volume.ID?
        var isNew: Bool { existingID == nil }
    }
    private var scanQueue: [ScanJob] = []

    func isScanning(_ volume: Volume) -> Bool {
        scanState?.volumeID == volume.id
    }

    struct ScanState: Equatable {
        var name: String
        var scanned: Int
        var volumeID: Volume.ID?
    }

    // MARK: - 存储路径

    private var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Cyan Clone", isDirectory: true)
    }

    /// 改名之前的位置，用来把已有索引搬过来
    private var legacySupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DriveShell", isDirectory: true)
    }

    private func migrateLegacyIndexIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: indexURL.path) else { return }
        let legacy = legacySupportDirectory.appendingPathComponent("index.json")
        guard fm.fileExists(atPath: legacy.path) else { return }
        try? fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try? fm.copyItem(at: legacy, to: indexURL)
    }

    /// 改名后 bundle id 变了，把旧的偏好（视图、上次位置、扫描深度）带过来
    static func migrateLegacyDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "ViewMode") == nil,
              defaults.object(forKey: "BrandVariant") == nil else { return }
        guard let legacy = UserDefaults(suiteName: "com.cyan.driveshell") else { return }
        for key in ["ViewMode", "LastPaths", "DefaultDepth", "ShowHidden", "Screen"] {
            if let value = legacy.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    private var indexURL: URL { supportDirectory.appendingPathComponent("index.json") }

    var indexFilePath: String { indexURL.path }

    // MARK: - 生命周期

    /// 双击 .cyan 时 AppDelegate 拿不到 SwiftUI 的 @StateObject，借这两个入口递过来
    static weak var shared: LibraryStore?
    static var pendingImport: URL?

    init() {
        LibraryStore.migrateLegacyDefaultsIfNeeded()
        migrateLegacyIndexIfNeeded()
        load()
        inspectorVisible = (screen == .browser)
        inspectorBeforePool = true
        LibraryStore.shared = self
        if let url = LibraryStore.pendingImport {
            LibraryStore.pendingImport = nil
            DispatchQueue.main.async { [weak self] in
                self?.importLibraryPackage(from: url)
            }
        }
    }

    func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: indexURL) else { return }
        guard let file = try? JSONDecoder().decode(LibraryFile.self, from: data) else { return }
        volumes = file.volumes
        for volume in volumes {
            volume.root.linkParents()
            if volume.root.total == 0 {
                volume.root.recomputeTotals()      // 兼容旧索引
            }
            volume.root.sortRecursively(key: sortKey, ascending: sortAscending)
        }
        if let first = volumes.first {
            selectedVolumeID = first.id
            restoreLocation(for: first)
        }
        // 在硬盘池里收起简介栏；回到浏览页时再展开
        inspectorVisible = (screen == .browser)
        inspectorBeforePool = true
    }

    // MARK: - 记住上次浏览位置

    private func persistLocation() {
        guard let volume = selectedVolume else { return }
        var dict = (UserDefaults.standard.dictionary(forKey: "LastPaths") as? [String: [String]]) ?? [:]
        dict[volume.id.uuidString] = path.map { $0.name }
        UserDefaults.standard.set(dict, forKey: "LastPaths")
    }

    func restoreLocation(for volume: Volume) {
        let dict = (UserDefaults.standard.dictionary(forKey: "LastPaths") as? [String: [String]]) ?? [:]
        guard let names = dict[volume.id.uuidString], !names.isEmpty else {
            path = []
            return
        }
        path = resolve(names: names, in: volume.root)
    }

    /// 按名字逐级找回路径（重新索引后旧节点对象已经失效）
    func resolve(names: [String], in root: Node) -> [Node] {
        var node = root
        var chain: [Node] = []
        for name in names {
            guard let next = (node.children ?? []).first(where: { $0.name == name && $0.isFolder }) else { break }
            chain.append(next)
            node = next
        }
        return chain
    }

    private func save() {
        let file = LibraryFile(version: 1, volumes: volumes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(file)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            errorMessage = "索引保存失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 当前状态

    var selectedVolume: Volume? {
        guard let id = selectedVolumeID else { return volumes.first }
        return volumes.first { $0.id == id }
    }

    var currentFolder: Node? {
        path.last ?? selectedVolume?.root
    }

    var currentTitle: String {
        if screen == .pool { return "硬盘池" }
        return path.last?.name ?? selectedVolume?.name ?? "Cyan Clone"
    }

    var poolSubtitle: String {
        guard !volumes.isEmpty else { return "还没有硬盘 · 点「＋」开始" }
        let devices = volumes.filter { $0.isDevice }.count
        let folders = volumes.count - devices
        let totalItems = volumes.reduce(0) { $0 + $1.itemCount }
        let totalSize = volumes.reduce(Int64(0)) { $0 + $1.totalBytes }
        let kind = folders == 0 ? "\(devices) 块硬盘" : "\(devices) 块硬盘 + \(folders) 个文件夹"
        return "\(kind) · 已索引 \(Fmt.bytes(totalSize)) · \(Fmt.count(totalItems)) 个项目"
    }

    var currentSubtitle: String {
        if screen == .pool { return poolSubtitle }
        guard let folder = currentFolder else { return "未选择硬盘" }
        let count = visibleChildren(of: folder).count
        return "\(count) 个项目 · 索引深度 \(selectedVolume?.maxDepth ?? 3) 级"
    }

    var canGoBack: Bool { !path.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    var selectedNode: Node? {
        guard let id = selectedNodeID else { return nil }
        if let folder = currentFolder, let hit = find(id: id, in: folder) { return hit }
        if let chainHit = columnChain.first(where: { $0.id == id }) { return chainHit }
        return nil
    }

    private func find(id: Node.ID, in node: Node) -> Node? {
        if node.id == id { return node }
        for child in node.children ?? [] {
            if let hit = find(id: id, in: child) { return hit }
        }
        return nil
    }

    func visibleChildren(of folder: Node) -> [Node] {
        let kids = folder.children ?? []
        return showHidden ? kids : kids.filter { !$0.isHiddenName }
    }

    func isMounted(_ volume: Volume) -> Bool {
        FileManager.default.fileExists(atPath: volume.path)
    }

    struct MountedVolume: Identifiable {
        var id: String { url.path }
        let name: String
        let url: URL
    }

    var mountedUnindexed: [MountedVolume] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: "/Volumes") else { return [] }
        let indexed = Set(volumes.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path })
        return names
            .filter { !$0.hasPrefix(".") }
            .map { "/Volumes/\($0)" }
            .filter { path in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: path, isDirectory: &isDir)
                return isDir.boolValue && !indexed.contains(URL(fileURLWithPath: path).standardizedFileURL.path)
            }
            .map { MountedVolume(name: ($0 as NSString).lastPathComponent, url: URL(fileURLWithPath: $0)) }
    }

    // MARK: - 导航

    func showPool() {
        if screen != .pool { inspectorBeforePool = inspectorVisible }
        searchScopeOverride = nil
        searchText = ""
        screen = .pool
        inspectorVisible = false
    }

    /// 回到浏览页时恢复简介栏状态
    private func enterBrowser() {
        if screen != .browser { inspectorVisible = inspectorBeforePool }
        screen = .browser
    }

    /// 从硬盘池点进某块盘，可指定落到哪个文件夹
    func openVolume(_ volume: Volume, at node: Node? = nil) {
        searchScopeOverride = nil
        selectedVolumeID = volume.id
        forwardStack = []
        if let node {
            var chain = node.chainToRoot()
            if !node.isFolder { chain = Array(chain.dropLast()) }
            path = chain
        } else {
            path = []
        }
        columnChain = []
        selectedNodeID = node?.id
        enterBrowser()
        persistLocation()
    }

    func selectVolume(_ id: Volume.ID?) {
        guard id != selectedVolumeID else {
            enterBrowser()
            return
        }
        enterBrowser()
        searchScopeOverride = nil
        selectedVolumeID = id
        forwardStack = []
        selectedNodeID = nil
        columnChain = []
        if let volume = volumes.first(where: { $0.id == id }) {
            restoreLocation(for: volume)
        } else {
            path = []
        }
    }

    func enter(_ node: Node) {
        guard node.isFolder else { return }
        forwardStack.removeAll()
        path.append(node)
        columnChain = []
        selectedNodeID = nil
        persistLocation()
    }

    func goBack() {
        guard let last = path.popLast() else { return }
        forwardStack.append(last)
        selectedNodeID = last.id
        columnChain = []
        persistLocation()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        path.append(next)
        selectedNodeID = next.id
        columnChain = []
        persistLocation()
    }

    /// 直接跳到某条目录链路（面包屑用）
    func go(to chain: [Node]) {
        forwardStack = []
        path = chain.filter { $0.isFolder }
        columnChain = []
        selectedNodeID = nil
        persistLocation()
    }

    func goUp() {
        if let last = path.popLast() {
            forwardStack.append(last)
            selectedNodeID = last.id
            columnChain = []
            persistLocation()
        }
    }

    func revealInFinder(_ node: Node) {
        guard let url = urlFor(node) else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "「\(node.name)」只是索引记录，原盘未挂载或文件已不存在。"
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 用当前路径拼出真实文件路径
    func urlFor(_ node: Node) -> URL? {
        guard let volume = selectedVolume else { return nil }
        let names = chainNames(for: node)
        var url = URL(fileURLWithPath: volume.path)
        for n in names { url.appendPathComponent(n) }
        return url
    }

    func chainNames(for node: Node) -> [String] {
        var names: [String] = []
        var cur: Node? = node
        while let c = cur, c.parent != nil {
            names.insert(c.name, at: 0)
            cur = c.parent
        }
        return names
    }

    func pathText(for node: Node) -> String {
        guard let volume = selectedVolume else { return node.name }
        let names = chainNames(for: node)
        if names.isEmpty { return volume.path }
        return ([volume.path] + names).joined(separator: "/")
    }

    func copyPath(_ node: Node) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(pathText(for: node), forType: .string)
    }

    func copyName(_ node: Node) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(node.name, forType: .string)
    }

    // MARK: - 排序 / 显示

    func applySort() {
        for volume in volumes {
            volume.root.sortRecursively(key: sortKey, ascending: sortAscending)
        }
        refreshToken += 1
    }

    func setSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        applySort()
    }

    // MARK: - 搜索

    var searchScope: SearchScope {
        if let override = searchScopeOverride { return override }
        return screen == .pool ? .all : .current
    }

    var searchScopeTitle: String {
        switch searchScope {
        case .all:
            return "全部硬盘"
        case .current:
            return selectedVolume?.name ?? "当前硬盘"
        }
    }

    struct SearchHit: Identifiable {
        let node: Node
        let ancestors: [Node]          // 从硬盘根开始
        let volumeName: String         // 显示名（可能是自定义的）
        var id: Node.ID { node.id }
        var parentPath: String {
            ancestors.dropFirst().map { $0.name }.joined(separator: " › ")
        }
        /// 硬盘名 › 一级 › 二级
        var displayPath: String {
            parentPath.isEmpty ? volumeName : "\(volumeName) › \(parentPath)"
        }
    }

    func search(_ query: String) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count > 0 else { return [] }
        var hits: [SearchHit] = []

        func walk(_ node: Node, ancestors: [Node], volumeName: String) {
            if hits.count >= 800 { return }
            for child in node.children ?? [] {
                if child.name.localizedStandardContains(q) {
                    hits.append(SearchHit(node: child, ancestors: ancestors, volumeName: volumeName))
                }
                if child.isFolder, (child.children?.isEmpty == false) {
                    walk(child, ancestors: ancestors + [child], volumeName: volumeName)
                }
            }
        }

        let targets: [Volume]
        if searchScope == .current, let current = selectedVolume {
            targets = [current]
        } else {
            targets = volumes
        }
        for volume in targets {
            walk(volume.root, ancestors: [volume.root], volumeName: volume.displayName)
        }
        return hits
    }

    /// 跳到某个搜索结果：切卷 + 逐级下钻 + 选中
    func jump(to hit: SearchHit) {
        guard let root = hit.ancestors.first,
              let volume = volumes.first(where: { $0.root.id == root.id }) else { return }
        selectedVolumeID = volume.id
        enterBrowser()
        forwardStack = []
        path = Array(hit.ancestors.dropFirst())   // 落到所在文件夹
        columnChain = [hit.node]                  // 分栏里直接展开这一项
        selectedNodeID = hit.node.id
        searchText = ""
        persistLocation()
    }

    // MARK: - 扫描

    func chooseVolumesToScan() {
        let panel = NSOpenPanel()
        panel.title = "选择要建立目录索引的硬盘"
        panel.message = "选中移动硬盘（或任意文件夹），只记录目录层级和文件名，不复制任何数据。当前索引深度：\(defaultDepth) 级。"
        panel.prompt = "开始扫描"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        if panel.runModal() == .OK {
            guard confirmHeavyScan(depth: defaultDepth, target: "所选硬盘") else { return }
            for url in panel.urls { startScan(url: url, depth: defaultDepth) }
        }
    }

    /// 等用户选深度的请求（右键菜单 → 小面板）。菜单动作里只登记请求，不在菜单跟踪中改状态。
    struct DepthRequest: Identifiable {
        let id = UUID()
        var volume: Volume
    }

    @Published var depthRequest: DepthRequest?

    /// 从右键菜单调用：等这一轮菜单收起后再弹面板
    func promptScanDepth(for volume: Volume) {
        DispatchQueue.main.async { [weak self] in
            self?.depthRequest = DepthRequest(volume: volume)
        }
    }

    func rescan(_ volume: Volume, depth: Int? = nil, at newURL: URL? = nil, confirm: Bool = true) {
        let url = newURL ?? URL(fileURLWithPath: volume.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "「\(volume.name)」当前没有挂载，请插上硬盘后再更新索引。"
            return
        }
        if confirm, let depth, depth >= 6 {
            guard confirmHeavyScan(depth: depth, target: volume.name) else { return }
        }
        startScan(url: url, depth: depth ?? volume.maxDepth, existingID: volume.id)
    }

    /// 深度很大的时候先问一句：会扫很久，但依然只读
    private func confirmHeavyScan(depth: Int, target: String) -> Bool {
        guard depth >= 6 else { return true }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "确定用 \(depth) 级深度扫描吗？"
        alert.informativeText = """
        「\(target)」在 \(depth) 级深度下可能收录几十万个条目：扫描时间更长，索引文件也更大。

        整个过程只读取文件名、大小和修改时间，不会打开文件内容，也不会改动盘上的任何东西。
        单次扫描最多收录 \(Fmt.count(Scanner.maxNodes)) 项，超出会自动停下。
        """
        alert.addButton(withTitle: "继续扫描")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 把所有已挂载的硬盘按各自的范围和深度重扫一遍
    func syncAll() {
        let targets = volumes.filter { isMounted($0) }
        guard !targets.isEmpty else {
            errorMessage = "没有已挂载的硬盘。插上硬盘后再试。"
            return
        }
        for volume in targets { rescan(volume, confirm: false) }
    }

    var lastSyncDate: Date? { volumes.map { $0.scannedAt }.max() }

    var lastSyncText: String {
        guard let date = lastSyncDate else { return "还没有同步过" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "yyyy/M/d HH:mm"
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "刚刚 · \(f.string(from: date))"
        }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "zh_Hans_CN")
        rel.unitsStyle = .short
        return "\(f.string(from: date))（\(rel.localizedString(for: date, relativeTo: Date()))）"
    }

    func startScan(url: URL, depth: Int? = nil, existingID: Volume.ID? = nil) {
        let levels = min(max(depth ?? defaultDepth, 1), 8)
        scanQueue.append(ScanJob(url: url, depth: levels, existingID: existingID))
        runNextScan()
    }

    private func runNextScan() {
        guard scanState == nil, !scanQueue.isEmpty else { return }
        let job = scanQueue.removeFirst()
        scanState = ScanState(name: job.url.lastPathComponent, scanned: 0, volumeID: job.existingID)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Scanner.scanVolume(at: job.url, depth: job.depth) { count in
                DispatchQueue.main.async {
                    guard let self, var state = self.scanState else { return }
                    state.scanned = count
                    self.scanState = state
                }
            }
            let when = Date()
            DispatchQueue.main.async {
                guard let self else { return }
                self.finishScan(result: result, url: job.url, depth: job.depth, date: when, existingID: job.existingID, isNew: job.isNew)
            }
        }
    }

    private func finishScan(result: Scanner.Result,
                            url: URL,
                            depth: Int,
                            date: Date,
                            existingID: Volume.ID?,
                            isNew: Bool) {
        result.root.sortRecursively(key: sortKey, ascending: sortAscending)
        result.root.linkParents()

        let previous = existingID.flatMap { id in volumes.first { $0.id == id } }
        let device = result.device

        let volume = Volume(id: existingID ?? UUID(),
                            name: url.lastPathComponent,
                            path: url.path,
                            scannedAt: date,
                            maxDepth: depth,
                            fileCount: result.fileCount,
                            folderCount: result.folderCount,
                            totalBytes: result.totalBytes,
                            capacity: result.capacity,
                            freeSpace: result.freeSpace,
                            scope: result.scope,
                            hostVolume: result.hostVolume,
                            deviceModel: device.model,
                            deviceBus: device.bus,
                            deviceLocation: device.location,
                            deviceMedium: device.medium,
                            deviceSerial: device.serial,
                            fileSystem: device.fileSystem,
                            customName: previous?.customName ?? "",
                            root: result.root)

        if let existingID, let idx = volumes.firstIndex(where: { $0.id == existingID }) {
            volumes[idx] = volume
        } else {
            volumes.append(volume)
        }

        save()
        scanState = nil
        sortVolumes()

        if isNew {
            selectedVolumeID = volume.id
            enterBrowser()
            path = []
            forwardStack = []
            columnChain = []
            selectedNodeID = nil
        } else if selectedVolumeID == volume.id {
            // 同步当前正在看的那块盘：尽量停在原来的文件夹
            let names = path.map { $0.name }
            path = resolve(names: names, in: volume.root)
            columnChain = []
            selectedNodeID = nil
            persistLocation()
        }
        refreshToken += 1

        if result.hitLimit {
            errorMessage = "「\(volume.name)」收录条目已达到 \(Fmt.count(Scanner.maxNodes)) 项上限，超出的部分没有记录。建议降低扫描深度，或改选更具体的文件夹。"
        }
        runNextScan()
    }

    /// 硬盘池里整盘排前面（已挂载优先），文件夹范围排后面
    private func sortVolumes() {
        volumes.sort { a, b in
            if a.isDevice != b.isDevice { return a.isDevice }
            let am = isMounted(a), bm = isMounted(b)
            if am != bm { return am }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// 导入 .cyan 之后把合并好的整库接管进来并落盘
    func adoptImportedVolumes(_ incoming: [Volume]) {
        volumes = incoming
        if selectedVolumeID == nil { selectedVolumeID = volumes.first?.id }
        for volume in volumes {
            if volume.root.total == 0 { volume.root.recomputeTotals() }
            volume.root.sortRecursively(key: sortKey, ascending: sortAscending)
        }
        save()
        sortVolumes()
        refreshToken += 1
    }

    func removeVolume(_ volume: Volume) {
        volumes.removeAll { $0.id == volume.id }
        if selectedVolumeID == volume.id {
            selectedVolumeID = volumes.first?.id
            path = []
            columnChain = []
            selectedNodeID = nil
        }
        save()
        refreshToken += 1
    }

    func renameVolume(_ volume: Volume, to newName: String) {
        guard let idx = volumes.firstIndex(where: { $0.id == volume.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        volumes[idx].customName = (trimmed.isEmpty || trimmed == volume.name) ? "" : trimmed
        save()
        refreshToken += 1
    }

    /// 弹窗重命名
    func promptRename(_ volume: Volume) {
        let alert = NSAlert()
        alert.messageText = volume.isDevice ? "重命名这块硬盘" : "重命名这个文件夹索引"
        alert.informativeText = "只改这个 App 里的显示名称，不会重命名硬盘本身。留空即恢复原名「\(volume.name)」。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .informational

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = volume.displayName
        field.placeholderString = volume.name
        field.font = .systemFont(ofSize: 13)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        if alert.runModal() == .alertFirstButtonReturn {
            renameVolume(volume, to: field.stringValue)
        }
    }
}

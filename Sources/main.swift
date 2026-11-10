import SwiftUI
import AppKit

// MARK: - 命令行模式（用于验证扫描结果 / 批量建索引）
//
//   CyanClone --scan /Volumes/MyDisk [--depth 3] [--out /tmp/index.json]

enum CLI {
    static func shouldRun() -> Bool {
        let args = CommandLine.arguments
        return args.contains("--scan")
            || args.contains("--cyan-out")
            || args.contains("--cyan-in")
            || args.contains("--export-table")
            || args.contains("--export-current")
    }

    static func run() -> Never {
        let args = CommandLine.arguments

        if let target = value("--cyan-out", in: args) { exportPackage(to: target) }
        if let source = value("--cyan-in", in: args) { importPackage(from: source, commit: args.contains("--commit")) }
        if let target = value("--export-table", in: args) {
            exportTable(to: target,
                        format: value("--format", in: args) ?? "xlsx",
                        recursive: args.contains("--recursive"))
        }
        if let target = value("--export-current", in: args) {
            exportCurrent(to: target,
                          format: value("--format", in: args) ?? "xlsx",
                          recursive: args.contains("--recursive"),
                          search: value("--search", in: args),
                          pool: args.contains("--pool"))
        }

        var path: String?
        var depth = 3
        var out: String?

        var i = 1
        while i < args.count {
            switch args[i] {
            case "--scan":
                if i + 1 < args.count { path = args[i + 1]; i += 1 }
            case "--depth":
                if i + 1 < args.count, let d = Int(args[i + 1]) { depth = d; i += 1 }
            case "--out":
                if i + 1 < args.count { out = args[i + 1]; i += 1 }
            default:
                break
            }
            i += 1
        }

        guard let path else {
            FileHandle.standardError.write(Data("用法: CyanClone --scan <路径> [--depth 3] [--out file.json]\n".utf8))
            exit(2)
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        let started = Date()
        print("扫描 \(url.path) （深度 \(depth) 级）…")

        let result = Scanner.scanVolume(at: url, depth: depth) { count in
            if count % 5000 == 0 { print("  … 已读取 \(count) 项") }
        }

        let volume = Volume(name: url.lastPathComponent,
                            path: url.path,
                            scannedAt: Date(),
                            maxDepth: depth,
                            fileCount: result.fileCount,
                            folderCount: result.folderCount,
                            totalBytes: result.totalBytes,
                            capacity: result.capacity,
                            freeSpace: result.freeSpace,
                            scope: result.scope,
                            hostVolume: result.hostVolume,
                            deviceModel: result.device.model,
                            deviceBus: result.device.bus,
                            deviceLocation: result.device.location,
                            deviceMedium: result.device.medium,
                            deviceSerial: result.device.serial,
                            fileSystem: result.device.fileSystem,
                            root: result.root)

        var summary = "完成（\(result.scope.title)）：\(result.folderCount) 个文件夹 / \(result.fileCount) 个文件 / \(Fmt.bytes(result.totalBytes))"
        if result.capacity > 0 {
            summary += "（卷容量 \(Fmt.bytes(result.capacity))，剩余 \(Fmt.bytes(result.freeSpace))）"
        }
        if !result.device.model.isEmpty { summary += "，设备：\(result.device.model)" }
        summary += "，用时 \(String(format: "%.2f", Date().timeIntervalSince(started)))s"
        print(summary)

        if let out {
            let encoder = JSONEncoder()
            let data = try! encoder.encode(LibraryFile(version: 2, volumes: [volume]))
            try! data.write(to: URL(fileURLWithPath: out))
            print("已写入 \(out)（\(Fmt.bytes(Int64(data.count)))）")
        }

        exit(0)
    }
    // MARK: 数据包 / 表格（无界面自检用）

    private static func value(_ flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func loadVolumes() -> [Volume] {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("Cyan Clone/index.json")
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LibraryFile.self, from: data) else { return [] }
        for volume in file.volumes {
            volume.root.linkParents()
            if volume.root.total == 0 { volume.root.recomputeTotals() }
        }
        return file.volumes
    }

    static func exportPackage(to path: String) -> Never {
        let volumes = loadVolumes()
        guard !volumes.isEmpty else {
            FileHandle.standardError.write(Data("没有索引可导出\n".utf8))
            exit(1)
        }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let package = CyanPackage(appVersion: "cli",
                                  exportedAt: Date(),
                                  hostName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
                                  volumes: volumes)
        do {
            try CyanPackage.write(package, to: url)
            let size = (try? Data(contentsOf: url).count) ?? 0
            print("已写入 \(url.path)（\(Fmt.bytes(Int64(size)))，\(volumes.count) 块硬盘）")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("写入失败：\(error)\n".utf8))
            exit(1)
        }
    }

    static func importPackage(from path: String, commit: Bool) -> Never {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            let package = try CyanPackage.read(from: url)
            var volumes = loadVolumes()
            let before = volumes.count
            let summary = CyanPackage.merge(package, into: &volumes)
            print("来源：\(package.hostName) · 导出于 \(ExportDate.text(package.exportedAt)) · 版本 \(package.appVersion)")
            print("包内 \(package.volumes.count) 块 / 本地原有 \(before) 块")
            print(summary.text)
            if commit {
                let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let target = base.appendingPathComponent("Cyan Clone/index.json")
                let data = try JSONEncoder().encode(LibraryFile(version: 2, volumes: volumes))
                try data.write(to: target, options: .atomic)
                print("已合并写入 \(target.path)")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("导入失败：\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    /// 走界面同一套表（LibraryStore.currentExportTable），验证菜单里的路径没写错
    static func exportCurrent(to path: String, format: String, recursive: Bool, search: String?, pool: Bool) -> Never {
        guard let fmt = ExportFormat(rawValue: format) else {
            FileHandle.standardError.write(Data("未知格式：\(format)\n".utf8))
            exit(2)
        }
        let table: ExportTable = MainActor.assumeIsolated {
            let store = LibraryStore()
            if let first = store.volumes.first {
                store.selectedVolumeID = first.id
                store.path = []
                store.screen = .browser
            }
            if pool { store.screen = .pool }
            if let search, !search.isEmpty { store.searchText = search }
            return store.currentExportTable(recursive: recursive)
        }
        do {
            let data = try ExportWriter.data(for: table, format: fmt)
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            try data.write(to: url)
            print("已写入 \(url.path)（\(Fmt.bytes(Int64(data.count)))，\(table.rows.count) 行，表名 \(table.sheet)）")
            for (k, v) in table.meta { print("  \(k)：\(v)") }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("导出失败：\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func exportTable(to path: String, format: String, recursive: Bool) -> Never {
        guard let fmt = ExportFormat(rawValue: format) else {
            FileHandle.standardError.write(Data("未知格式：\(format)（xlsx/csv/json/markdown/text）\n".utf8))
            exit(2)
        }
        let volumes = loadVolumes()
        guard let volume = volumes.first else {
            FileHandle.standardError.write(Data("没有索引可导出\n".utf8))
            exit(1)
        }

        var rows: [[ExportCell]] = []
        func walk(_ node: Node, prefix: String) {
            for child in (node.children ?? []).sorted(by: { Node.nameIsOrdered($0, $1) }) {
                let childPath = ExportPath.join(prefix, child.name)
                rows.append([
                    .text(child.name),
                    .text(child.kindName),
                    .number(child.total),
                    .text(Fmt.size(child)),
                    .date(child.date),
                    child.isFolder ? .number(Int64(child.childCount)) : .empty,
                    .text(childPath)
                ])
                if recursive, child.isFolder { walk(child, prefix: childPath) }
            }
        }
        walk(volume.root, prefix: volume.path)

        let table = ExportTable(
            name: volume.displayName,
            sheet: volume.displayName,
            columns: [
                ExportColumn(title: "名称", width: 42),
                ExportColumn(title: "种类", width: 18),
                ExportColumn(title: "大小（字节）", kind: .bytes),
                ExportColumn(title: "大小", width: 12),
                ExportColumn(title: "修改日期", width: 18),
                ExportColumn(title: "项数", kind: .number, width: 8),
                ExportColumn(title: "路径", width: 54)
            ],
            rows: rows,
            meta: [("导出时间", ExportDate.text(Date())),
                   ("来源", volume.displayName),
                   ("项目数", "\(rows.count)")]
        )
        do {
            let data = try ExportWriter.data(for: table, format: fmt)
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            try data.write(to: url)
            print("已写入 \(url.path)（\(Fmt.bytes(Int64(data.count)))，\(rows.count) 行，\(fmt.rawValue)）")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("导出失败：\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

if CLI.shouldRun() {
    CLI.run()
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 启动 Sparkle 自动更新（后台按 SUFeedURL 检查；见 Sources/Updater.swift）
        MainActor.assumeIsolated { _ = UpdaterController.shared }

        // 自检用：--import <文件> 启动后直接导入
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--import"), i + 1 < args.count {
            let url = URL(fileURLWithPath: (args[i + 1] as NSString).expandingTildeInPath)
            if let store = LibraryStore.shared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    store.importLibraryPackage(from: url)
                }
            } else {
                LibraryStore.pendingImport = url
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// 双击 .cyan（或拖到 Dock 图标上）：读包 → 合并
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "cyan" || $0.lastPathComponent == "index.json" })
        else { return }
        if let store = LibraryStore.shared {
            // 等主窗口起来再弹结果，否则模态框会被开机流程吞掉
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                store.importLibraryPackage(from: url)
            }
        } else {
            LibraryStore.pendingImport = url
        }
    }
}

struct CyanCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        Window("Cyan Clone", id: "main") {
            ContentView()
                .environmentObject(library)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 Cyan Clone") { AboutPanel.show() }
            }
            CommandGroup(replacing: .newItem) {
                Button("添加硬盘…") {
                    library.chooseVolumesToScan()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .importExport) {
                Button("导出当前结果…") { library.exportCurrentResults() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(library.volumes.isEmpty)
                Divider()
                Button("导出数据文件（.cyan）…") { library.exportLibraryPackage() }
                    .disabled(library.volumes.isEmpty)
                Button("导入数据文件（.cyan）…") { library.promptImportPackage() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Picker("视图", selection: $library.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("上一层") { library.goUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
            }
        }
    }
}

CyanCloneApp.main()

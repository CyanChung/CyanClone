import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI

// MARK: - 把「当前结果」拼成一张表

extension LibraryStore {

    /// 导出的上限：再大就不是「当前结果」而是备份了，备份走 .cyan
    static let exportRowLimit = 200_000

    /// 当前页面的表：搜索结果 / 文件夹清单 / 硬盘池
    func currentExportTable(recursive: Bool) -> ExportTable {
        if !searchText.isEmpty {
            return searchTable()
        }
        if screen == .pool {
            return poolTable()
        }
        return folderTable(recursive: recursive)
    }

    var currentExportBaseName: String {
        if !searchText.isEmpty { return "搜索-\(searchText)" }
        if screen == .pool { return "硬盘池" }
        return currentFolder?.name ?? "清单"
    }

    /// 当前上下文能不能选「包含子文件夹」
    var currentExportAllowsRecursive: Bool {
        searchText.isEmpty && screen == .browser
    }

    // MARK: 搜索结果

    private func searchTable() -> ExportTable {
        let hits = search(searchText)
        var rows: [[ExportCell]] = []
        rows.reserveCapacity(hits.count)
        for hit in hits {
            let node = hit.node
            rows.append([
                .text(node.name),
                .text(node.kindName),
                .number(node.total),
                .text(Fmt.size(node)),
                .date(node.date),
                .text(hit.displayPath),
                .empty
            ])
        }
        var meta: [(String, String)] = [
            ("导出时间", ExportDate.text(Date())),
            ("来源", "搜索结果「\(searchText)」"),
            ("搜索范围", searchScopeTitle),
            ("行数", "\(rows.count)")
        ]
        if hits.count >= 800 {
            meta.append(("提示", "搜索结果上限 800 条，更多请缩小关键词"))
        }
        return ExportTable(
            name: currentExportBaseName,
            sheet: "搜索结果",
            columns: itemColumns,
            rows: rows,
            meta: meta
        )
    }

    // MARK: 文件夹

    private func folderTable(recursive: Bool) -> ExportTable {
        guard let folder = currentFolder else {
            return ExportTable(name: "清单", sheet: "清单", columns: itemColumns, rows: [])
        }
        let volume = selectedVolume
        let rootPath = pathText(for: folder)
        var rows: [[ExportCell]] = []
        var truncated = false

        func row(_ node: Node, path: String) -> [ExportCell] {
            var cells: [ExportCell] = [
                .text(node.name),
                .text(node.kindName),
                .number(node.total),
                .text(Fmt.size(node)),
                .date(node.date),
                .empty,
                .text(path)
            ]
            if node.isFolder { cells[5] = .number(Int64(node.childCount)) }
            return cells
        }

        func walk(_ node: Node, prefix: String) {
            for child in (node.children ?? []) {
                if !showHidden && child.isHiddenName { continue }
                if rows.count >= LibraryStore.exportRowLimit { truncated = true; return }
                let childPath = ExportPath.join(prefix, child.name)
                rows.append(row(child, path: childPath))
                if recursive, child.isFolder, child.children?.isEmpty == false {
                    walk(child, prefix: childPath)
                }
            }
        }

        walk(folder, prefix: rootPath)

        var meta: [(String, String)] = [
            ("导出时间", ExportDate.text(Date())),
            ("来源", folder === volume?.root ? "硬盘「\(volume?.displayName ?? "")」根目录" : "文件夹「\(rootPath)」"),
            ("范围", recursive ? "含所有子文件夹" : "仅当前一层"),
            ("项目数", "\(rows.count)")
        ]
        if let volume {
            meta.append(("索引时间", volume.scannedText))
            meta.append(("索引深度", volume.depthText))
        }
        if truncated { meta.append(("提示", "已达 \(LibraryStore.exportRowLimit) 行上限，其余未导出")) }

        return ExportTable(
            name: currentExportBaseName,
            sheet: folder.name,
            columns: itemColumns,
            rows: rows,
            meta: meta,
            truncated: truncated
        )
    }

    // MARK: 硬盘池

    private func poolTable() -> ExportTable {
        var rows: [[ExportCell]] = []
        for volume in volumes {
            rows.append([
                .text(volume.displayName),
                .text(volume.isDevice ? "整盘" : "文件夹"),
                .number(volume.capacity),
                .number(volume.usedBytes),
                .number(volume.totalBytes),
                .number(Int64(volume.fileCount)),
                .number(Int64(volume.folderCount)),
                .number(Int64(volume.maxDepth)),
                .date(volume.scannedAt),
                .text(isMounted(volume) ? "已挂载" : "未挂载"),
                .text(volume.path)
            ])
        }
        let meta: [(String, String)] = [
            ("导出时间", ExportDate.text(Date())),
            ("来源", "硬盘池"),
            ("硬盘数", "\(volumes.count)"),
            ("已索引总量", Fmt.bytes(volumes.reduce(Int64(0)) { $0 + $1.totalBytes }))
        ]
        return ExportTable(
            name: currentExportBaseName,
            sheet: "硬盘池",
            columns: [
                ExportColumn(title: "名称"),
                ExportColumn(title: "类型"),
                ExportColumn(title: "容量（字节）", kind: .bytes),
                ExportColumn(title: "已用（字节）", kind: .bytes),
                ExportColumn(title: "索引大小（字节）", kind: .bytes),
                ExportColumn(title: "文件数", kind: .number),
                ExportColumn(title: "文件夹数", kind: .number),
                ExportColumn(title: "深度", kind: .number, width: 8),
                ExportColumn(title: "索引时间"),
                ExportColumn(title: "状态"),
                ExportColumn(title: "路径", width: 48)
            ],
            rows: rows,
            meta: meta
        )
    }

    private var itemColumns: [ExportColumn] {
        [
            ExportColumn(title: "名称", width: 42),
            ExportColumn(title: "种类", width: 18),
            ExportColumn(title: "大小（字节）", kind: .bytes),
            ExportColumn(title: "大小", width: 12),
            ExportColumn(title: "修改日期", width: 18),
            ExportColumn(title: "项数", kind: .number, width: 8),
            ExportColumn(title: "路径", width: 54)
        ]
    }
}

// MARK: - 导出面板

@MainActor
enum ExportPanel {

    /// 保存面板：格式下拉 + 「包含子文件夹」
    static func ask(baseName: String, allowRecursive: Bool) -> (format: ExportFormat, recursive: Bool, url: URL)? {
        let panel = NSSavePanel()
        panel.title = "导出当前结果"
        panel.message = allowRecursive
            ? "选格式后保存；「包含所有子文件夹」会把整棵目录树摊平成表格。"
            : "选格式后保存。"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        let controller = OptionsController(baseName: baseName, allowRecursive: allowRecursive)
        controller.panel = panel
        panel.accessoryView = controller.makeView()
        controller.apply(to: .xlsx)

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return (controller.format, controller.recursive, url)
    }

    @MainActor
    private final class OptionsController: NSObject {
        let baseName: String
        let allowRecursive: Bool
        weak var panel: NSSavePanel?

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 24), pullsDown: false)
        let recuseBox = NSButton(checkboxWithTitle: "包含所有子文件夹的内容（整棵树摊平）",
                                 target: nil, action: nil)

        init(baseName: String, allowRecursive: Bool) {
            self.baseName = baseName
            self.allowRecursive = allowRecursive
        }

        var format: ExportFormat {
            ExportFormat.allCases[max(0, min(popup.indexOfSelectedItem, ExportFormat.allCases.count - 1))]
        }

        var recursive: Bool { allowRecursive && recuseBox.state == .on }

        func makeView() -> NSView {
            for f in ExportFormat.allCases {
                popup.addItem(withTitle: f.title)
            }
            popup.target = self
            popup.action = #selector(formatChanged)

            recuseBox.state = .off
            recuseBox.isHidden = !allowRecursive
            recuseBox.font = .systemFont(ofSize: 12)

            let formatLabel = NSTextField(labelWithString: "格式")
            formatLabel.font = .systemFont(ofSize: 12)
            formatLabel.textColor = .secondaryLabelColor
            formatLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            let row = NSStackView(views: [formatLabel, popup])
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .firstBaseline

            let stack = NSStackView(views: allowRecursive ? [row, recuseBox] : [row])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 6
            stack.edgeInsets = NSEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
            stack.frame = NSRect(x: 0, y: 0, width: 430, height: allowRecursive ? 66 : 44)
            return stack
        }

        @objc func formatChanged() {
            apply(to: format)
        }

        func apply(to format: ExportFormat) {
            guard let panel else { return }
            panel.allowedContentTypes = [format.contentType]
            let stem = (baseName as NSString).deletingPathExtension
            panel.nameFieldStringValue = "\(stem).\(format.ext)"
        }
    }
}

// MARK: - 入口（菜单 / 工具栏都调这里）

extension LibraryStore {

    func exportCurrentResults() {
        let allowRecursive = currentExportAllowsRecursive
        let stem = "\(currentExportBaseName)-\(ExportDate.fileStamp.string(from: Date()))"
        guard let choice = ExportPanel.ask(baseName: stem, allowRecursive: allowRecursive) else { return }

        let table = currentExportTable(recursive: choice.recursive)
        guard !table.rows.isEmpty else {
            errorMessage = "当前页面没有可导出的内容。"
            return
        }
        do {
            let data = try ExportWriter.data(for: table, format: choice.format)
            try data.write(to: choice.url)
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            announceExport(url: choice.url, count: table.rows.count, size: size)
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func announceExport(url: URL, count: Int, size: String) {
        let alert = NSAlert()
        alert.messageText = "已导出 \(Fmt.count(count)) 项"
        alert.informativeText = "\(url.lastPathComponent) · \(size)\n\(url.deletingLastPathComponent().path)"
        alert.addButton(withTitle: "在访达中显示")
        alert.addButton(withTitle: "好")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

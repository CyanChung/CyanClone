import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - .cyan 数据包
//
// 换电脑的场景：把整个索引库（多块硬盘的目录树、硬件信息、自定义名字）
// 打成一个自包含的文件，拷到另一台机器上双击就能导进来。
//
// 文件结构（小端无所谓，全部按网络序写死）：
//   0..3     "CYAN"          魔数
//   4        u8              容器版本（1）
//   5        u8              载荷编码（0 = 明文 JSON，1 = zlib 压缩）
//   6..13    u64             解压后的 JSON 字节数
//   14..     载荷
// 魔数不对时按明文 JSON 再试一次 —— 这样旧版直接导出的 index.json 也能读。

struct CyanPackage: Codable {
    var format: String = "cyan-library"
    var formatVersion: Int = 1
    var appVersion: String = ""
    var exportedAt: Date = Date()
    var hostName: String = ""
    var volumes: [Volume] = []

    struct Summary {
        var added: [String] = []
        var updated: [String] = []
        var keptLocal: [String] = []
        var unchanged: [String] = []
        var total: Int { added.count + updated.count }

        var text: String {
            var lines: [String] = []
            if !added.isEmpty { lines.append("新增 \(added.count) 块：\(added.joined(separator: "、"))") }
            if !updated.isEmpty { lines.append("更新 \(updated.count) 块：\(updated.joined(separator: "、"))") }
            if !keptLocal.isEmpty { lines.append("本地更新，已保留：\(keptLocal.joined(separator: "、"))") }
            if !unchanged.isEmpty { lines.append("没有变化 \(unchanged.count) 块") }
            return lines.isEmpty ? "没有可导入的硬盘。" : lines.joined(separator: "\n")
        }
    }

    enum PackageError: LocalizedError {
        case notACyanFile
        case unsupportedVersion(Int)
        case corrupt

        var errorDescription: String? {
            switch self {
            case .notACyanFile:
                return "这不是 Cyan Clone 的数据文件（缺少 CYAN 标记）。"
            case .unsupportedVersion(let v):
                return "这份数据文件来自更新的版本（容器 v\(v)），请先升级 Cyan Clone。"
            case .corrupt:
                return "数据文件已损坏，读不出里面的索引。"
            }
        }
    }

    static let magic = Array("CYAN".utf8)
    static let containerVersion: UInt8 = 1
    static let codecRaw: UInt8 = 0
    static let codecZlib: UInt8 = 1

    // MARK: 写

    static func write(_ package: CyanPackage, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let json = try encoder.encode(package)
        let compressed = (try? (json as NSData).compressed(using: .zlib) as Data) ?? json
        let useZlib = compressed.count < json.count

        var out = Data()
        out.append(contentsOf: magic)
        out.append(containerVersion)
        out.append(useZlib ? codecZlib : codecRaw)
        var length = UInt64(json.count).bigEndian
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(useZlib ? compressed : json)
        try out.write(to: url, options: .atomic)
    }

    // MARK: 读

    static func read(from url: URL) throws -> CyanPackage {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if data.count > 14, Array(data.prefix(4)) == magic {
            let version = data[4]
            guard version <= containerVersion else { throw PackageError.unsupportedVersion(Int(version)) }
            let codec = data[5]
            var length: UInt64 = 0
            _ = withUnsafeMutableBytes(of: &length) { data.copyBytes(to: $0, from: 6..<14) }
            length = UInt64(bigEndian: length)
            let payload = data.subdata(in: 14..<data.count)
            var json = payload
            if codec == codecZlib {
                guard let raw = try? (payload as NSData).decompressed(using: .zlib) as Data else {
                    throw PackageError.corrupt
                }
                json = raw
            } else if codec != codecRaw {
                throw PackageError.corrupt
            }
            guard let package = try? decoder.decode(CyanPackage.self, from: json) else {
                throw PackageError.corrupt
            }
            linkParents(in: package)
            return package
        }

        // 退路：明文 JSON（老版本的 index.json / 手工拼的文件）
        if let package = try? decoder.decode(CyanPackage.self, from: data) {
            linkParents(in: package)
            return package
        }
        if let file = try? decoder.decode(LibraryFile.self, from: data) {
            let package = CyanPackage(appVersion: "", exportedAt: Date(), hostName: "", volumes: file.volumes)
            linkParents(in: package)
            return package
        }
        throw PackageError.notACyanFile
    }

    private static func linkParents(in package: CyanPackage) {
        for volume in package.volumes {
            volume.root.linkParents()
        }
    }

    // MARK: 合并

    /// 同一块硬盘（UUID 相同，或路径相同）以「索引时间更新的那份」为准；
    /// 其余直接加进来。返回这次动了什么。
    static func merge(_ package: CyanPackage, into volumes: inout [Volume]) -> Summary {
        var summary = Summary()
        for incoming in package.volumes {
            let path = URL(fileURLWithPath: incoming.path).standardizedFileURL.path
            let index = volumes.firstIndex { local in
                local.id == incoming.id
                    || URL(fileURLWithPath: local.path).standardizedFileURL.path == path
            }

            guard let index else {
                volumes.append(incoming)
                summary.added.append(incoming.displayName)
                continue
            }

            let local = volumes[index]
            let sameContent = incoming.scannedAt == local.scannedAt
                && incoming.totalBytes == local.totalBytes
                && incoming.fileCount == local.fileCount
                && incoming.folderCount == local.folderCount
            if sameContent {
                summary.unchanged.append(local.displayName)
            } else if incoming.scannedAt >= local.scannedAt {
                var merged = incoming
                // 本地改过的名字别丢
                if merged.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    merged.customName = local.customName
                }
                merged.id = local.id          // 沿用本地 UUID，界面上的选中状态不会错乱
                volumes[index] = merged
                summary.updated.append(merged.displayName)
            } else {
                summary.keptLocal.append(local.displayName)
            }
        }
        return summary
    }
}

// MARK: - 导入 / 导出（菜单、工具栏、双击 .cyan 都走这里）

extension LibraryStore {

    static let cyanType = UTType(exportedAs: "com.cyan.cyanclone.library", conformingTo: .data)

    var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var hostName: String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    // MARK: 导出

    func exportLibraryPackage() {
        guard !volumes.isEmpty else {
            errorMessage = "还没有可以导出的索引。先添加一块硬盘。"
            return
        }
        let panel = NSSavePanel()
        panel.title = "导出数据文件"
        panel.message = "一个文件带走全部索引（\(volumes.count) 块硬盘）。换电脑后双击它即可导入。"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [LibraryStore.cyanType]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let stamp = ExportDate.fileStamp.string(from: Date())
        panel.nameFieldStringValue = "Cyan-Clone-\(stamp).cyan"

        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension.lowercased() != "cyan" {
            url = url.appendingPathExtension("cyan")
        }

        let package = CyanPackage(appVersion: appVersionText,
                                  exportedAt: Date(),
                                  hostName: hostName,
                                  volumes: volumes)
        do {
            try CyanPackage.write(package, to: url)
            let size = (try? Data(contentsOf: url).count) ?? 0
            let items = volumes.reduce(0) { $0 + $1.itemCount }
            let alert = NSAlert()
            alert.messageText = "已导出数据文件"
            alert.informativeText = """
            \(url.lastPathComponent)
            \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) · \
            \(volumes.count) 块硬盘 · \(Fmt.count(items)) 个项目

            换电脑后装上 Cyan Clone，把这份文件双击打开即可导入。
            """
            alert.addButton(withTitle: "在访达中显示")
            alert.addButton(withTitle: "好")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: 导入

    func promptImportPackage() {
        let panel = NSOpenPanel()
        panel.title = "导入数据文件"
        panel.message = "选择 .cyan 数据文件（旧版导出的 index.json 也可以）。"
        panel.prompt = "导入"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [LibraryStore.cyanType, .json]
        if panel.runModal() == .OK, let url = panel.url {
            importLibraryPackage(from: url)
        }
    }

    /// 真正干活：读 → 合并 → 落盘。commit = false 时只在内存里试（命令行自检用）
    @discardableResult
    func importLibraryPackage(from url: URL, commit: Bool = true) -> CyanPackage.Summary? {
        do {
            let package = try CyanPackage.read(from: url)
            var working = volumes
            let summary = CyanPackage.merge(package, into: &working)
            guard commit else { return summary }

            adoptImportedVolumes(working)

            let alert = NSAlert()
            alert.messageText = summary.total > 0 ? "已导入 \(summary.total) 块硬盘" : "索引已是最新"
            var lines = [summary.text]
            lines.append("")
            lines.append("来源：\(package.hostName.isEmpty ? "未知电脑" : package.hostName) · 导出于 \(ExportDate.text(package.exportedAt))")
            alert.informativeText = lines.joined(separator: "\n")
            alert.addButton(withTitle: "好")
            alert.runModal()
            return summary
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
            return nil
        }
    }
}

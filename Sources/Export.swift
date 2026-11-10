import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI

// MARK: - 导出：当前结果 → 表格 / 文本
//
// 五种格式共用同一张「表」：
//   · Excel（.xlsx）—— 冻结表头、自动筛选、列宽按内容、字节列可直接求和
//   · CSV（.csv）—— 带 BOM，Excel / Numbers / 飞书表格都能直接打开
//   · JSON（.json）—— 机器可读，带元信息，方便再加工
//   · Markdown（.md）—— 贴进文档、Notion、GitHub 都是表
//   · 纯文本（.txt）—— 制表符分隔，粘到聊天窗口不会乱

enum ExportFormat: String, CaseIterable, Identifiable {
    case xlsx, csv, json, markdown, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xlsx:     return "Excel 工作簿（.xlsx）"
        case .csv:      return "CSV（.csv）"
        case .json:     return "JSON（.json）"
        case .markdown: return "Markdown 表格（.md）"
        case .text:     return "纯文本清单（.txt）"
        }
    }

    var ext: String {
        switch self {
        case .xlsx:     return "xlsx"
        case .csv:      return "csv"
        case .json:     return "json"
        case .markdown: return "md"
        case .text:     return "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .xlsx:
            return UTType(filenameExtension: "xlsx")
                ?? UTType("org.openxmlformats.spreadsheetml.sheet")
                ?? .data
        case .csv:
            return .commaSeparatedText
        case .json:
            return .json
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .text:
            return .plainText
        }
    }
}

// MARK: - 表结构

enum CellKind {
    case text
    case bytes        // 字节数，写进 Excel 是数字
    case number
    case date
}

struct ExportColumn {
    var title: String
    var kind: CellKind = .text
    var width: CGFloat = 0      // 0 = 按内容自动
}

enum ExportCell {
    case text(String)
    case number(Int64)
    case date(Date)
    case empty

    var plainText: String {
        switch self {
        case .text(let s):   return s
        case .number(let n): return String(n)
        case .date(let d):   return ExportDate.text(d)
        case .empty:         return ""
        }
    }
}

struct ExportTable {
    /// 面板标题与文件名主干
    var name: String
    /// 表名（Excel 的 sheet 名）
    var sheet: String
    var columns: [ExportColumn]
    var rows: [[ExportCell]]
    /// 写进 JSON / 文本头部的说明行
    var meta: [(String, String)] = []
    /// 行数被截断过就记一笔
    var truncated = false
}

enum ExportPath {
    /// 拼路径：根是「/」时不要拼出「//Users」
    static func join(_ prefix: String, _ name: String) -> String {
        if prefix.isEmpty { return name }
        return prefix.hasSuffix("/") ? prefix + name : prefix + "/" + name
    }
}

enum ExportDate {
    static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func text(_ d: Date) -> String {
        d.timeIntervalSince1970 <= 0 ? "" : stamp.string(from: d)
    }
}

// MARK: - 写各种格式

enum ExportWriter {

    static func data(for table: ExportTable, format: ExportFormat) throws -> Data {
        switch format {
        case .xlsx:     return try XLSX.build(table)
        case .csv:      return Data(csv(table).utf8)
        case .json:     return Data(json(table).utf8)
        case .markdown: return Data(markdown(table).utf8)
        case .text:     return Data(text(table).utf8)
        }
    }

    // MARK: CSV

    static func csv(_ table: ExportTable) -> String {
        var out = "\u{FEFF}"      // BOM：Windows 版 Excel 靠它认 UTF-8
        out += table.columns.map { quote($0.title) }.joined(separator: ",") + "\r\n"
        for row in table.rows {
            out += row.map { quote($0.plainText) }.joined(separator: ",") + "\r\n"
        }
        return out
    }

    private static func quote(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    // MARK: JSON

    static func json(_ table: ExportTable) -> String {
        var root: [String: Any] = [:]
        var meta: [String: Any] = [:]
        for (k, v) in table.meta { meta[k] = v }
        meta["列"] = table.columns.map { $0.title }
        meta["行数"] = table.rows.count
        if table.truncated { meta["已截断"] = true }
        root["表"] = table.sheet
        root["元信息"] = meta

        var items: [[String: Any]] = []
        items.reserveCapacity(table.rows.count)
        for row in table.rows {
            var obj: [String: Any] = [:]
            for (i, column) in table.columns.enumerated() {
                let cell = i < row.count ? row[i] : .empty
                switch cell {
                case .empty:
                    obj[column.title] = NSNull()
                case .text(let s):
                    obj[column.title] = s
                case .number(let n):
                    obj[column.title] = NSNumber(value: n)
                case .date(let d):
                    obj[column.title] = ExportDate.text(d)
                }
            }
            items.append(obj)
        }
        root["数据"] = items

        let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: opts),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: Markdown

    static func markdown(_ table: ExportTable) -> String {
        var out = "# \(table.sheet)\n\n"
        if !table.meta.isEmpty {
            for (k, v) in table.meta { out += "- \(k)：\(v)\n" }
            out += "\n"
        }
        out += "| " + table.columns.map { escapePipe($0.title) }.joined(separator: " | ") + " |\n"
        out += "|" + table.columns.map { column in
            column.kind == .bytes || column.kind == .number ? " ---: " : " --- "
        }.joined(separator: "|") + "|\n"
        for row in table.rows {
            let cells = table.columns.enumerated().map { i, _ in
                escapePipe(i < row.count ? row[i].plainText : "")
            }
            out += "| " + cells.joined(separator: " | ") + " |\n"
        }
        if table.truncated { out += "\n> 行数已达上限，其余未导出。\n" }
        return out
    }

    private static func escapePipe(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
    }

    // MARK: 纯文本

    static func text(_ table: ExportTable) -> String {
        var out = ""
        if !table.meta.isEmpty {
            for (k, v) in table.meta { out += "\(k)：\(v)\n" }
            out += String(repeating: "—", count: 32) + "\n"
        }
        out += table.columns.map { $0.title }.joined(separator: "\t") + "\n"
        for row in table.rows {
            out += table.columns.enumerated()
                .map { i, _ in i < row.count ? row[i].plainText : "" }
                .joined(separator: "\t") + "\n"
        }
        return out
    }
}

// MARK: - XLSX（自己拼 OOXML，不依赖第三方库）

enum XLSXError: LocalizedError {
    case zipFailed
    var errorDescription: String? {
        switch self {
        case .zipFailed: return "打包 xlsx 失败"
        }
    }
}

enum XLSX {

    static func build(_ table: ExportTable) throws -> Data {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("cyan-xlsx-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        try write(sheet(table), to: dir.appendingPathComponent("xl/worksheets/sheet1.xml"))
        try write(contentTypes, to: dir.appendingPathComponent("[Content_Types].xml"))
        try write(rootRels, to: dir.appendingPathComponent("_rels/.rels"))
        try write(workbook(table.sheet), to: dir.appendingPathComponent("xl/workbook.xml"))
        try write(workbookRels, to: dir.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try write(styles, to: dir.appendingPathComponent("xl/styles.xml"))

        let out = fm.temporaryDirectory.appendingPathComponent("cyan-\(UUID().uuidString).xlsx")
        try zip(directory: dir, to: out)
        defer { try? fm.removeItem(at: out) }
        return try Data(contentsOf: out)
    }

    private static func write(_ xml: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: url)
    }

    private static func zip(directory: URL, to output: URL) throws {
        let fm = FileManager.default
        let zipTool = "/usr/bin/zip"
        if fm.isExecutableFile(atPath: zipTool) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: zipTool)
            p.currentDirectoryURL = directory
            p.arguments = ["-q", "-X", "-r", output.path, "[Content_Types].xml", "_rels", "xl"]
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0, fm.fileExists(atPath: output.path) { return }
        }
        // 退路：ditto 也能打 zip（会把目录名带进去，所以先 cd 到父目录再指定内容）
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--sequesterRsrc", directory.path, output.path]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0, fm.fileExists(atPath: output.path) else {
            throw XLSXError.zipFailed
        }
    }

    // MARK: 各部件

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0"/></numFmts>
      <fonts count="2">
        <font><sz val="11"/><color theme="1"/><name val="PingFang SC"/></font>
        <font><b/><sz val="11"/><color theme="1"/><name val="PingFang SC"/></font>
      </fonts>
      <fills count="3">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFEFEFEF"/><bgColor indexed="64"/></patternFill></fill>
      </fills>
      <borders count="1"><border/></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="3">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
        <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
      </cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """

    private static func workbook(_ sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="\(escape(sheetName))" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
    }

    private static func sheet(_ table: ExportTable) -> String {
        let cols = table.columns.count
        let lastCol = columnName(cols)
        let lastRow = max(1, table.rows.count + 1)

        // 列宽：按内容的显示宽度估（中文按 2 个字符算）
        var widths: [Int] = table.columns.map { displayWidth($0.title) }
        for row in table.rows.prefix(400) {
            for (i, cell) in row.enumerated() where i < cols {
                widths[i] = max(widths[i], displayWidth(cell.plainText))
            }
        }

        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="A1:\(lastCol)\(lastRow)"/>
          <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
          <sheetFormatPr defaultRowHeight="16"/>
          <cols>
        """
        for (i, column) in table.columns.enumerated() {
            let w = column.width > 0 ? Int(column.width) : min(58, max(9, widths[i] + 2))
            xml += "\n    <col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(w)\" customWidth=\"1\"/>"
        }
        xml += "\n  </cols>\n  <sheetData>\n"

        // 表头
        xml += "    <row r=\"1\">"
        for (i, column) in table.columns.enumerated() {
            xml += cellXML(ref: "\(columnName(i + 1))1", style: 1, inline: column.title)
        }
        xml += "</row>\n"

        for (r, row) in table.rows.enumerated() {
            let rowIndex = r + 2
            xml += "    <row r=\"\(rowIndex)\">"
            for (i, column) in table.columns.enumerated() {
                let cell = i < row.count ? row[i] : .empty
                let ref = "\(columnName(i + 1))\(rowIndex)"
                switch cell {
                case .empty:
                    continue
                case .text(let s):
                    xml += cellXML(ref: ref, style: 0, inline: s)
                case .number(let n):
                    let style = column.kind == .bytes ? 2 : 0
                    xml += "<c r=\"\(ref)\"\(style > 0 ? " s=\"\(style)\"" : "")><v>\(n)</v></c>"
                case .date(let d):
                    xml += cellXML(ref: ref, style: 0, inline: ExportDate.text(d))
                }
            }
            xml += "</row>\n"
        }

        xml += """
          </sheetData>
          <autoFilter ref="A1:\(lastCol)\(lastRow)"/>
        </worksheet>
        """
        return xml
    }

    private static func cellXML(ref: String, style: Int, inline: String) -> String {
        let s = style > 0 ? " s=\"\(style)\"" : ""
        return "<c r=\"\(ref)\"\(s) t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(inline))</t></is></c>"
    }

    private static func columnName(_ index: Int) -> String {
        var n = index
        var name = ""
        while n > 0 {
            let r = (n - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + r))) + name
            n = (n - 1) / 26
        }
        return name
    }

    private static func displayWidth(_ s: String) -> Int {
        var w = 0
        for ch in s.unicodeScalars {
            w += ch.value > 0x2E80 ? 2 : 1
        }
        return min(w, 120)
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                // XML 1.0 不接受的控制字符直接丢掉
                if let v = ch.unicodeScalars.first?.value, v < 0x20, v != 0x09, v != 0x0A, v != 0x0D {
                    continue
                }
                out.append(ch)
            }
        }
        return out
    }
}

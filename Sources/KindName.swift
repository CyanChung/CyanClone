import Foundation

// MARK: - 种类名称（尽量贴近 Finder 的说法）

enum KindName {
    private static let table: [String: String] = [
        // 图像
        "jpg": "JPEG 图像", "jpeg": "JPEG 图像", "jpe": "JPEG 图像",
        "png": "PNG 图像", "gif": "GIF 图像", "bmp": "BMP 图像",
        "heic": "HEIF 图像", "heif": "HEIF 图像", "tif": "TIFF 图像", "tiff": "TIFF 图像",
        "webp": "WebP 图像", "svg": "SVG 图像", "psd": "Photoshop 图像",
        "ai": "Illustrator 绘图", "eps": "EPS 图像", "raw": "RAW 图像",
        "cr2": "Canon RAW 图像", "cr3": "Canon RAW 图像", "nef": "Nikon RAW 图像",
        "arw": "Sony RAW 图像", "dng": "DNG 图像", "orf": "Olympus RAW 图像",
        // 视频
        "mp4": "MPEG-4 影片", "m4v": "MPEG-4 影片", "mov": "QuickTime 影片",
        "qt": "QuickTime 影片", "avi": "AVI 影片", "mkv": "Matroska 视频",
        "mxf": "MXF 视频", "mts": "AVCHD 视频", "m2ts": "AVCHD 视频",
        "r3d": "RED 视频", "braw": "Blackmagic RAW 视频", "crm": "Canon RAW 视频",
        "mpg": "MPEG 影片", "mpeg": "MPEG 影片", "wmv": "Windows Media 视频",
        "flv": "Flash 视频", "webm": "WebM 视频", "insv": "Insta360 视频",
        "lrf": "LRT 视频", "prproj": "Premiere Pro 项目", "aep": "After Effects 项目",
        "fcpxml": "Final Cut Pro XML", "fcpproject": "Final Cut Pro 资源库",
        "drp": "DaVinci Resolve 项目", "xml": "XML 文稿", "edl": "EDL 剪辑表",
        // 音频
        "wav": "WAV 音频", "mp3": "MP3 音频", "aif": "AIFF 音频", "aiff": "AIFF 音频",
        "m4a": "MPEG-4 音频", "aac": "AAC 音频", "flac": "FLAC 音频",
        "caf": "CAF 音频", "aup3": "Audacity 项目",
        // 文档
        "pdf": "PDF 文稿", "txt": "文本文稿", "rtf": "RTF 文稿", "rtfd": "RTF 文稿",
        "md": "Markdown 文稿", "csv": "CSV 文稿", "tsv": "TSV 文稿",
        "doc": "Word 文稿", "docx": "Word 文稿", "dot": "Word 模板",
        "xls": "Excel 工作表", "xlsx": "Excel 工作表", "numbers": "Numbers 表格",
        "ppt": "PowerPoint 演示文稿", "pptx": "PowerPoint 演示文稿",
        "key": "Keynote 演示文稿", "pages": "Pages 文稿",
        "json": "JSON 文稿", "html": "HTML 文稿", "htm": "HTML 文稿",
        "srt": "SRT 字幕", "ass": "ASS 字幕", "vtt": "VTT 字幕",
        // 归档 / 镜像
        "zip": "ZIP 归档", "rar": "RAR 归档", "7z": "7-Zip 归档",
        "tar": "TAR 归档", "gz": "Gzip 归档", "dmg": "磁盘映像",
        "iso": "光盘映像", "pkg": "安装包", "app": "应用程序",
        "exe": "Windows 应用程序", "torrent": "BitTorrent 文件",
        // 其他
        "lrc": "LRC 歌词", "cube": "LUT 调色文件", "icc": "色彩描述文件",
    ]

    static func describe(node: Node) -> String {
        switch node.kind {
        case .folder:
            return "文件夹"
        case .symlink:
            return "替身"
        case .file:
            if node.ext.isEmpty { return "文稿" }
            if let s = table[node.ext] { return s }
            return "\(node.ext.uppercased()) 文件"
        }
    }
}

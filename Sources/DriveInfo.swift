import Foundation
import IOKit

/// 读取磁盘的硬件信息（型号 / 总线 / 介质 / 文件系统）。
/// 全部通过 IOKit 与 statfs 只读查询，不启动任何外部命令。
enum DriveInfo {

    struct Snapshot {
        var model: String = ""
        var vendor: String = ""
        var bus: String = ""          // USB / PCI-Express / Apple Fabric …
        var location: String = ""     // Internal / External
        var medium: String = ""       // Solid State / Rotational
        var serial: String = ""
        var fileSystem: String = ""   // APFS / exFAT / NTFS …
        var bsdName: String = ""      // disk5s1
        var isVirtual: Bool = false   // 磁盘映像 / 网络卷

        var isExternal: Bool { location.caseInsensitiveCompare("External") == .orderedSame }

        /// 卡片上显示的一行：型号 · 总线 · 文件系统
        var summary: String {
            var parts: [String] = []
            if !model.isEmpty { parts.append(model) }
            let busText = DriveInfo.busLabel(bus, isVirtual: isVirtual)
            if !busText.isEmpty { parts.append(busText) }
            if !fileSystem.isEmpty { parts.append(fileSystem) }
            return parts.isEmpty ? "型号未识别" : parts.joined(separator: " · ")
        }
    }

    static func busLabel(_ raw: String, isVirtual: Bool) -> String {
        if isVirtual { return "磁盘映像" }
        switch raw {
        case "USB": return "USB"
        case "PCI-Express": return "PCIe"
        case "Apple Fabric": return "内置总线"
        case "SATA": return "SATA"
        case "Virtual Interface": return "虚拟"
        case "": return ""
        default: return raw
        }
    }

    // MARK: - 探测

    static func probe(path: String) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.fileSystem = fileSystemName(path)

        guard let bsd = bsdName(forPath: path) else { return snapshot }
        snapshot.bsdName = bsd
        guard let matching = IOBSDNameMatching(kIOMainPortDefault, 0, bsd) else { return snapshot }
        var service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return snapshot }

        var product = ""
        var vendor = ""
        var bus = ""
        var location = ""
        var medium = ""
        var serial = ""
        var level = 0

        while service != 0 && level < 14 {
            var className = [CChar](repeating: 0, count: 128)
            IOObjectGetClass(service, &className)
            let cls = String(cString: className)
            if cls.contains("DiskImage") || cls.contains("HDIX") {
                snapshot.isVirtual = true
            }

            if let props = properties(of: service) {
                if product.isEmpty, let chars = props["Device Characteristics"] as? [String: Any] {
                    product = text(chars["Product Name"])
                    vendor = text(chars["Vendor Name"])
                    medium = text(chars["Medium Type"])
                    if serial.isEmpty { serial = text(chars["Serial Number"]) }
                }
                if product.isEmpty {
                    let usbProduct = text(props["USB Product Name"])
                    if !usbProduct.isEmpty {
                        product = usbProduct
                        if vendor.isEmpty { vendor = text(props["USB Vendor Name"]) }
                    }
                }
                if product.isEmpty { product = text(props["Product Name"]) }
                if vendor.isEmpty { vendor = text(props["Vendor Name"]) }
                if bus.isEmpty { bus = text(props["Physical Interconnect"]) }
                if location.isEmpty { location = text(props["Physical Interconnect Location"]) }
                if serial.isEmpty { serial = text(props["Serial Number"]) }
            }

            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)
            IOObjectRelease(service)
            if result != KERN_SUCCESS {
                service = 0
                break
            }
            service = parent
            level += 1
        }

        if product.isEmpty && snapshot.isVirtual { product = "磁盘映像" }

        // 厂商名已经在型号里就不再重复拼
        var model = product
        if !vendor.isEmpty && !product.lowercased().contains(vendor.lowercased()) {
            model = vendor + " " + product
        }

        snapshot.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.vendor = vendor
        snapshot.bus = bus
        snapshot.location = location
        snapshot.medium = medium
        snapshot.serial = serial
        return snapshot
    }

    // MARK: - 底层

    private static func properties(of service: io_registry_entry_t) -> [String: Any]? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanaged?.takeRetainedValue() as? [String: Any] else { return nil }
        return dict
    }

    private static func text(_ value: Any?) -> String {
        switch value {
        case let s as String:
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case let n as NSNumber:
            return n.stringValue
        case let d as Data:
            return String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        default:
            return ""
        }
    }

    /// 挂载点对应的 BSD 设备名，例如 disk5s2
    static func bsdName(forPath path: String) -> String? {
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return nil }
        let from = withUnsafePointer(to: &fs.f_mntfromname) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        guard from.hasPrefix("/dev/") else { return nil }   // 网络卷没有本地设备
        return URL(fileURLWithPath: from).lastPathComponent
    }

    static func fileSystemName(_ path: String) -> String {
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return "" }
        let raw = withUnsafePointer(to: &fs.f_fstypename) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) { String(cString: $0) }
        }
        switch raw {
        case "apfs": return "APFS"
        case "hfs": return "HFS+"
        case "exfat": return "exFAT"
        case "msdos": return "FAT32"
        case "ntfs": return "NTFS"
        case "smbfs", "afpfs", "nfs": return "网络卷"
        default: return raw.uppercased()
        }
    }
}

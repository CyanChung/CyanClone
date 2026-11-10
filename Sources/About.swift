import SwiftUI
import AppKit

// MARK: - 关于窗口

/// 自己搭一个面板，不再走系统的 orderFrontStandardAboutPanel：
/// 系统那版把版本号硬塞在名字下面（「Version x (n)」），字号字重都不受控，看着很粗鲁。
/// 这里改成：图标 / 名字 / 版本（小字、宽字距、极淡）/ 一句说明 / 写信给作者。
/// 小篆只留在侧栏彩蛋，这个窗口里不再出现。
enum AboutPanel {
    private static var window: NSWindow?

    @MainActor
    static func show() {
        if window == nil { window = makeWindow() }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private static func makeWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: AboutView())
        let size = hosting.fittingSize
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable],
                         backing: .buffered,
                         defer: false)
        w.title = "关于 Cyan Clone"
        w.isReleasedWhenClosed = false
        w.backgroundColor = .windowBackgroundColor
        w.contentView = hosting
        w.contentMinSize = size
        w.contentMaxSize = size
        return w
    }
}

private struct AboutView: View {
    /// 发布日：写死在这里，改版时跟着版本号一起改
    private static let releaseDate = "2026.11.10"

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return v.isEmpty ? Self.releaseDate : "\(v)（\(Self.releaseDate)）"
    }

    // 直接从 bundle 里读 icns：NSApp.applicationIconImage 会被系统的图标缓存拖住旧版
    private var icon: NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 0) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }

            // 名字居中；版本紧贴其下，小字 + 宽字距 + 淡色——是脚注，不是第二行标题
            Text("Cyan Clone")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 22)

            Text(version)
                .font(.system(size: 9, weight: .regular))
                .tracking(1.8)
                .foregroundStyle(.tertiary)
                .padding(.top, 5)

            Text("本地索引，数据不出本机")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 14)

            Button {
                UpdaterController.shared.checkForUpdates()
            } label: {
                Text("检查更新")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 18)
            .help("从 GitHub Releases 检查是否有新版本")

            MailRow()
                .padding(.top, 16)
        }
        .padding(.top, 30)
        .padding(.bottom, 26)
        .frame(width: 316)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 写信给作者：图标 + 地址，点哪都跳系统邮件
private struct MailRow: View {
    static let email = "finalcut@agent.qq.com"
    @State private var hovering = false

    var body: some View {
        Button {
            var comps = URLComponents()
            comps.scheme = "mailto"
            comps.path = Self.email
            comps.queryItems = [URLQueryItem(name: "subject", value: "Cyan Clone")]
            if let url = comps.url { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "envelope")
                    .font(.system(size: 10.5, weight: .medium))
                Text(Self.email)
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.2)
                    .underline(hovering, color: .secondary)
            }
            .foregroundStyle(hovering ? Color.secondary : Color.secondary.opacity(0.75))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("写信给作者 · \(Self.email)")
    }
}

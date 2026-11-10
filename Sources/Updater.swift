import AppKit
import Sparkle

// MARK: - Sparkle 自动更新

/// 全局唯一的 Sparkle 更新控制器。
///
/// `SPUStandardUpdaterController` 用主 bundle + Sparkle 标准界面，
/// 按 Info.plist 里的 `SUFeedURL`（GitHub Releases 上的 appcast.xml）自动检查更新；
/// 启动时按 `SUEnableAutomaticChecks` 后台检查，用户点「检查更新」则即时弹框。
/// 强引用必须常驻，否则控制器一释放，自动更新就停了。
@MainActor
final class UpdaterController {
    static let shared = UpdaterController()

    private let sparkle: SPUStandardUpdaterController

    private init() {
        sparkle = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// 手动触发一次「检查更新」，弹 Sparkle 标准进度与结果框。
    func checkForUpdates() {
        sparkle.checkForUpdates(nil)
    }
}

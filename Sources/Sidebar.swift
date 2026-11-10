import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var lib: LibraryStore

    private var selectionBinding: Binding<Volume.ID?> {
        Binding(
            get: { lib.selectedVolumeID },
            set: { lib.selectVolume($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
            Section {
                navRow(title: "硬盘池",
                       symbol: "circle.grid.2x2.fill",
                       active: lib.screen == .pool,
                       trailing: "\(lib.volumes.count)") {
                    lib.showPool()
                }
            }

            Section {
                ForEach(lib.volumes) { volume in
                    row(for: volume)
                        .tag(volume.id)
                        .contextMenu {
                            Button("浏览") { lib.openVolume(volume) }
                            Button("重命名显示名称…") { lib.promptRename(volume) }
                            if volume.hasCustomName {
                                Button("恢复原名「\(volume.name)」") { lib.renameVolume(volume, to: "") }
                            }
                            Button("更新索引（\(volume.maxDepth) 级）") { lib.rescan(volume) }
                            Button("更改索引深度…") { lib.promptScanDepth(for: volume) }
                            Divider()
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: volume.path))
                            }
                            Button("移除索引", role: .destructive) { lib.removeVolume(volume) }
                        }
                }
                if lib.volumes.isEmpty {
                    Text("还没有硬盘")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }
            } header: {
                Text("硬盘")
            }

            if !lib.mountedUnindexed.isEmpty {
                Section("已挂载 · 未索引") {
                    ForEach(lib.mountedUnindexed, id: \.url.path) { item in
                        Button {
                            lib.startScan(url: item.url)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "externaldrive.badge.plus")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(item.name)
                                    .font(.system(size: 12.5))
                                    .lineLimit(1)
                                Spacer()
                                Text("扫描")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    lib.chooseVolumesToScan()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                        Text("添加硬盘…")
                            .font(.system(size: 12.5))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            }
            .listStyle(.sidebar)

            Divider()
                .opacity(0.5)

            BrandFooter()
        }
    }

    private func navRow(title: String,
                        symbol: String,
                        active: Bool,
                        trailing: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(active ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5))
                Spacer(minLength: 4)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(active ? Color.accentColor.opacity(0.16) : Color.clear)
    }

    @ViewBuilder
    private func row(for volume: Volume) -> some View {
        HStack(spacing: 7) {
            Image(nsImage: IconProvider.shared.sidebarImage(for: volume))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(volume.displayName)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(volume.scope.title) · \(Fmt.count(volume.itemCount)) 项 · \(volume.depthText)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if !lib.isMounted(volume) {
                Image(systemName: "eject")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .help("未挂载，仅可浏览索引")
            }
        }
        .padding(.vertical, 1)
        .help(sidebarHelp(for: volume))
    }

    private func sidebarHelp(for volume: Volume) -> String {
        var lines: [String] = [volume.displayName]
        if volume.hasCustomName { lines.append("原名：\(volume.name)") }
        if !volume.deviceSummary.isEmpty { lines.append(volume.deviceSummary) }
        lines.append(volume.path)
        return lines.joined(separator: "\n")
    }
}

// MARK: - 侧栏底栏：小 C + 彩蛋

/// 左边一个 C：点一下在月亮 / 星芒 / 太阳里随机换一个，并轻轻弹一下。
/// 中间空白处每次点击浮现「星漢燦爛」（小篆，3 秒淡出）；
/// 第 1、3、5、7、9… 次（奇数次）点击，字四周会炸一小圈金色礼花，偶数次只有字。
struct BrandFooter: View {
    @EnvironmentObject var lib: LibraryStore

    @State private var bounceTrigger = 0
    @State private var clickCount = 0
    @State private var eggVisible = false
    @State private var fadeTask: Task<Void, Never>? = nil

    var body: some View {
        // 侧栏宽度是可拖动的，彩蛋的尺寸得按实际宽度算：
        // 用 GeometryReader 读出这一行的宽度，再反推小篆能占多高（宽高比固定，绝不压扁）。
        GeometryReader { geo in
            row(width: geo.size.width)
        }
        // 高度必须等于内容自然高度（42 的 C + 上下各 5 的命中留白 + 上下各 6 的呼吸），
        // 写小了整行会被垂直挤压，C 和小篆就一起往下坠、贴着窗口底边。
        .frame(height: 64)
    }

    /// 小篆能用的字高：减掉 C、版本号、间距和内边距，剩下的宽度除以宽高比
    private func sealHeight(for width: CGFloat) -> CGFloat {
        let reserved: CGFloat = 52 + 12 + 20   // C 块 + 两处间距 + 左右内边距
        let room = max(0, width - reserved)
        return min(32, max(15, room / SealArt.aspect))
    }

    private func row(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Button { tap() } label: {
                PhaseAnimator([1.0, 1.18, 0.97, 1.0], trigger: bounceTrigger) { scale in
                    BrandMark(variant: lib.brandVariant, compact: true)
                        .frame(width: 42, height: 42)
                        .scaleEffect(scale)
                } animation: { _ in
                    .spring(response: 0.22, dampingFraction: 0.55)
                }
                .padding(5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(0.65)
            .help("现在是「\(lib.brandVariant.title)」· 点击随机换一个")

            Spacer(minLength: 0)

            if eggVisible {
                // 星漢燦爛：用设计给的描线稿，字高随侧栏宽度伸缩
                SealArt.Stars(height: sealHeight(for: width),
                              color: Color.primary.opacity(0.78))
                    .overlay {
                        // 奇数次点击（第 1、3、5… 次）才放大礼花，偶数次只出字
                        if clickCount % 2 == 1 {
                            SparkleBurst(seed: clickCount)
                        }
                    }
                    .id(clickCount)               // 同样的文字也要重新播淡入
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

        }
        .frame(maxHeight: .infinity)      // 整行在底栏里垂直居中，不靠上下 padding 顶
        .padding(.horizontal, 10)
        .animation(.easeInOut(duration: 0.35), value: eggVisible)
        .animation(.easeInOut(duration: 0.35), value: clickCount)
    }

    private func tap() {
        let others = BrandVariant.allCases.filter { $0 != lib.brandVariant }
        if let next = others.randomElement() {
            lib.setBrandVariant(next)
            bounceTrigger += 1
        }

        clickCount += 1
        eggVisible = true

        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { eggVisible = false }
        }
    }

}

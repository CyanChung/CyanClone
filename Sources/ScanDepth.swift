import SwiftUI

/// 改索引深度的小面板。
///
/// 以前深度是右键菜单里的二级菜单（1–8 级），点一下就直接重扫：菜单还在收起的过程中
/// 就改了 store 里的数据、高超 6 级还会在菜单动作里弹 NSAlert，macOS 上这套组合很容易
/// 把 App 带崩。现在菜单只打开这个面板，选层级、确认高层级、启动扫描都在面板里完成。
struct ScanDepthSheet: View {
    @EnvironmentObject var lib: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let volume: Volume
    @State private var depth: Int

    init(volume: Volume) {
        self.volume = volume
        _depth = State(initialValue: volume.maxDepth)
    }

    private var isHeavy: Bool { depth >= 6 }
    private var isMounted: Bool { FileManager.default.fileExists(atPath: volume.path) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            picker
            explain
            if isHeavy { heavyNote }
            if !isMounted { unmountedNote }
            footer
        }
        .padding(20)
        .frame(width: 396)
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("索引深度")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 6) {
                Text(volume.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text("现在 \(volume.depthText) · \(Fmt.count(volume.itemCount)) 项")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text(volume.path)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.bottom, 16)
    }

    // MARK: 1–8 级

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(1...8, id: \.self) { level in
                Button {
                    depth = level
                } label: {
                    Text("\(level)")
                        .font(.system(size: 12, weight: level == depth ? .semibold : .regular))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(level == depth ? BrandVariant.accent : Color.primary.opacity(0.06))
                        }
                        .foregroundStyle(level == depth ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(level == volume.maxDepth ? "\(level) 级（当前）" : "\(level) 级")
            }
        }
    }

    private var explain: some View {
        Text("3 级 = 盘根 → 一级 → 二级 → 三级。深度越大，能翻到的层数越多，索引里的条目也越多。\n只记录目录名、文件名、大小和修改时间，不复制也不改动盘上的任何东西。")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    private var heavyNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("\(depth) 级可能收录几十万个条目：扫描更久，索引文件也更大。单次最多收录 \(Fmt.count(Scanner.maxNodes)) 项，超出会自动停下。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        }
        .padding(.top, 10)
    }

    private var unmountedNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("这块盘现在没挂载。插上之后再扫描才能更新索引；现在只能改记录里的深度值。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .padding(.top, 10)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(depth == volume.maxDepth ? "重新扫描（\(depth) 级）" : "改为 \(depth) 级") {
                start()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isMounted && depth == volume.maxDepth)
        }
        .padding(.top, 18)
    }

    // MARK: 启动

    private func start() {
        let target = volume
        let level = depth
        dismiss()
        // 等面板收完再动数据：面板还在收的时候替换 volumes / 起扫描，容易和视图更新撞车
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            LibraryStore.shared?.rescan(target, depth: level, confirm: false)
        }
    }
}

import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var lib: LibraryStore

    private var node: Node? { lib.selectedNode ?? lib.currentFolder }

    var body: some View {
        ScrollView {
            if let node {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 10) {
                        Image(nsImage: IconProvider.shared.icon(for: node))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

                        Text(node.name)
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 16)

                    Divider()

                    VStack(spacing: 9) {
                        infoRow("种类", node.kindName)
                        infoRow("大小", sizeText(for: node))
                        if node.isFolder {
                            if node.truncated {
                                infoRow("包含", "未索引（深度上限）")
                            } else {
                                infoRow("包含", "\(Fmt.count(node.childCount)) 项")
                            }
                        }
                        infoRow("修改时间", Fmt.date(node))
                        infoRow("层级", depthText(for: node))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        Text("位置")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(lib.pathText(for: node))
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if node.truncated && node.isFolder {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                            Text("已到索引深度（3 级），此项内部未展开。")
                                .font(.system(size: 10.5))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }

                    VStack(spacing: 8) {
                        Button {
                            lib.copyPath(node)
                        } label: {
                            Label("复制路径", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.regular)

                        Button {
                            lib.revealInFinder(node)
                        } label: {
                            Label("在 Finder 中显示", systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.regular)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text("选中一项以查看信息")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
        .background(.regularMaterial)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
            Text(value)
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func sizeText(for node: Node) -> String {
        if node.kind == .symlink { return "--" }
        if node.total < 0 { return "未能读取" }
        guard node.total > 0 else {
            return node.isFolder ? "--" : Fmt.bytes(max(0, node.size))
        }
        let base = Fmt.bytes(node.total)
        return node.isFolder && node.partial ? "≥ \(base)" : base
    }

    private func depthText(for node: Node) -> String {
        let depth = lib.chainNames(for: node).count
        if depth == 0 { return "硬盘根目录" }
        return depth == 1 ? "一级" : "第 \(depth) 级"
    }
}

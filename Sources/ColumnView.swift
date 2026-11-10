import SwiftUI

// MARK: - 分栏视图（Finder 的分栏浏览）

struct FinderColumnView: View {
    @EnvironmentObject var lib: LibraryStore

    /// 每列选中的那一项；只影响列的展开，不改变"当前位置"
    private var chain: [Node] { lib.columnChain }

    private var columns: [[Node]] {
        guard let base = lib.currentFolder else { return [] }
        var cols: [[Node]] = [lib.visibleChildren(of: base)]
        for node in chain where node.isFolder {
            cols.append(lib.visibleChildren(of: node))
        }
        return cols
    }

    var body: some View {
        let cols = columns
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(Array(cols.enumerated()), id: \.offset) { index, items in
                        column(items: items, index: index)
                            .id(index)
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 1)
                    }
                }
            }
            .onChange(of: cols.count) { _, newCount in
                guard newCount > 0 else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newCount - 1, anchor: .trailing)
                }
            }
        }
    }

    private func column(items: [Node], index: Int) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 4)
                ForEach(items) { node in
                    let isSelected = chain.indices.contains(index) && chain[index].id == node.id
                    HStack(spacing: 6) {
                        Image(nsImage: IconProvider.shared.icon(for: node))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        Text(node.name)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        Spacer(minLength: 4)
                        if node.isFolder && node.childCount > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.accentColor)
                                .padding(.horizontal, 4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(node, column: index) }
                    .contextMenu {
                        if node.isFolder {
                            Button("打开") { lib.enter(node) }
                        } else {
                            Button("在 Finder 中显示") { lib.revealInFinder(node) }
                        }
                        Button("复制名称") { lib.copyName(node) }
                        Button("复制路径") { lib.copyPath(node) }
                    }
                    .help(node.name)
                }
                Color.clear.frame(height: 8)
            }
        }
        .frame(width: 268)
    }

    private func select(_ node: Node, column index: Int) {
        // 只展开右侧的列，不动导航状态（和 Finder 的分栏一致）
        var newChain = Array(chain.prefix(index))
        newChain.append(node)
        lib.columnChain = newChain
        lib.selectedNodeID = node.id
    }
}

// MARK: - 图标视图

struct FinderIconView: View {
    @EnvironmentObject var lib: LibraryStore

    private var items: [Node] {
        guard let folder = lib.currentFolder else { return [] }
        return lib.visibleChildren(of: folder)
    }

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 8)]

    var body: some View {
        ScrollView {
            let list = items
            if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text(lib.currentFolder?.truncated == true ? "索引到这一层为止" : "此文件夹是空的")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(list) { node in
                        cell(node)
                    }
                }
                .padding(14)
            }
        }
    }

    private func cell(_ node: Node) -> some View {
        let isSelected = lib.selectedNodeID == node.id
        return VStack(spacing: 5) {
            Image(nsImage: IconProvider.shared.icon(for: node))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .padding(5)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                }

            Text(node.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected && true ? Color.accentColor : Color.clear)
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .frame(minWidth: 96, maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if node.isFolder { lib.enter(node) } else { lib.revealInFinder(node) }
        }
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            lib.selectedNodeID = node.id
        })
        .contextMenu {
            if node.isFolder {
                Button("打开") { lib.enter(node) }
            } else {
                Button("在 Finder 中显示") { lib.revealInFinder(node) }
            }
            Button("复制名称") { lib.copyName(node) }
            Button("复制路径") { lib.copyPath(node) }
        }
        .help("\(node.name)\n\(node.kindName)")
    }
}

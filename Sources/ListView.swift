import SwiftUI
import AppKit

// MARK: - 列表视图（Finder 列表的等价物）

struct FinderListView: View {
    @EnvironmentObject var lib: LibraryStore

    @State private var expanded: Set<Node.ID> = []
    @State private var hovered: Node.ID?
    @FocusState private var focused: Bool

    private struct Row: Identifiable {
        let node: Node
        let depth: Int
        let index: Int
        var id: Node.ID { node.id }
    }

    private var rows: [Row] {
        guard let folder = lib.currentFolder else { return [] }
        var out: [Row] = []
        func walk(_ parent: Node, depth: Int) {
            for child in lib.visibleChildren(of: parent) {
                out.append(Row(node: child, depth: depth, index: out.count))
                if child.isFolder, expanded.contains(child.id),
                   let kids = child.children, !kids.isEmpty {
                    walk(child, depth: depth + 1)
                }
            }
        }
        walk(folder, depth: 0)
        return out
    }

    var body: some View {
        let items = rows
        VStack(spacing: 0) {
            header
            Divider()

            if items.isEmpty {
                emptyPlaceholder
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { row in
                            rowView(row, total: items.count)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { lib.selectedNodeID = nil }
                )
            }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onChange(of: lib.currentFolder?.id) { _, _ in
            expanded.removeAll()
            focused = true
        }
        .onChange(of: lib.selectedVolumeID) { _, _ in expanded.removeAll() }
        .onKeyPress(.downArrow) { move(1, in: items); return .handled }
        .onKeyPress(.upArrow) { move(-1, in: items); return .handled }
        .onKeyPress(.rightArrow) {
            guard let node = lib.selectedNode else { return .ignored }
            if node.isFolder, node.childCount > 0 { expanded.insert(node.id) }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard let node = lib.selectedNode else { return .ignored }
            if node.isFolder, expanded.contains(node.id) { expanded.remove(node.id) }
            else { lib.goUp() }
            return .handled
        }
        .onKeyPress(.return) { openSelected(); return .handled }
    }

    // MARK: 表头

    private var header: some View {
        HStack(spacing: 0) {
            sortHeader(.name, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
            sortHeader(.date, alignment: .leading)
                .frame(width: 150, alignment: .leading)
            sortHeader(.size, alignment: .trailing)
                .frame(width: 96, alignment: .trailing)
                .padding(.trailing, 10)
            sortHeader(.kind, alignment: .leading)
                .frame(width: 128, alignment: .leading)
                .padding(.trailing, 6)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(height: 24)
        .background(Color.primary.opacity(0.045))
    }

    private func sortHeader(_ key: SortKey, alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 3) {
            if lib.sortKey == key {
                Image(systemName: lib.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            Text(key.title)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
        .contentShape(Rectangle())
        .onTapGesture { lib.setSort(key) }
    }

    // MARK: 行

    private func rowView(_ row: Row, total: Int) -> some View {
        let node = row.node
        let isSelected = lib.selectedNodeID == node.id
        let isHovered = hovered == node.id
        let canExpand = node.isFolder && node.childCount > 0
        let isExpanded = expanded.contains(node.id)

        return HStack(spacing: 0) {
            Color.clear.frame(width: CGFloat(row.depth) * 15 + 6)

            ZStack {
                if canExpand {
                    Button {
                        if isExpanded { expanded.remove(node.id) } else { expanded.insert(node.id) }
                    } label: {
                        DisclosureTriangle(expanded: isExpanded,
                                           color: isSelected ? .white.opacity(0.9) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 14, height: 16)

            Image(nsImage: IconProvider.shared.icon(for: node))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .padding(.leading, 2)

            Text(node.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Spacer(minLength: 8)

            Text(Fmt.date(node))
                .font(.system(size: 11.5))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            Text(Fmt.size(node))
                .font(.system(size: 11.5))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)
                .padding(.trailing, 10)

            Text(node.kindName)
                .font(.system(size: 11.5))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 128, alignment: .leading)
                .padding(.trailing, 6)
        }
        .frame(height: 24)
        .background {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor)
                        .padding(.horizontal, 4)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                        .padding(.horizontal, 4)
                } else if row.index % 2 == 1 {
                    Color.primary.opacity(0.022)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            hovered = inside ? node.id : (hovered == node.id ? nil : hovered)
        }
        .onTapGesture(count: 2) { open(node) }
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            lib.selectedNodeID = node.id
            lib.columnChain = []
            focused = true
        })
        .contextMenu { contextMenu(for: node) }
        .help(node.truncated && node.isFolder ? "已到达索引深度，未继续展开" : node.name)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 13) {
            Image(systemName: "folder")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(lib.currentFolder?.truncated == true ? "索引到这一层为止" : "此文件夹是空的")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            if lib.currentFolder?.truncated == true {
                Text("索引固定记录 3 级目录，更深的层级不会被保存。")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 交互

    private func open(_ node: Node) {
        if node.isFolder {
            lib.enter(node)
        } else {
            lib.revealInFinder(node)
        }
    }

    private func openSelected() {
        guard let node = lib.selectedNode else { return }
        open(node)
    }

    private func move(_ delta: Int, in items: [Row]) {
        guard !items.isEmpty else { return }
        if let current = lib.selectedNodeID, let idx = items.firstIndex(where: { $0.id == current }) {
            let next = min(max(idx + delta, 0), items.count - 1)
            lib.selectedNodeID = items[next].id
        } else {
            lib.selectedNodeID = items[0].id
        }
    }

    @ViewBuilder
    private func contextMenu(for node: Node) -> some View {
        if node.isFolder {
            Button("打开") { lib.enter(node) }
        } else {
            Button("在 Finder 中显示") { lib.revealInFinder(node) }
        }
        Button("复制名称") { lib.copyName(node) }
        Button("复制路径") { lib.copyPath(node) }
        Divider()
        Button("显示简介") {
            lib.selectedNodeID = node.id
            lib.inspectorVisible = true
        }
    }
}

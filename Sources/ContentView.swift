import SwiftUI

struct ContentView: View {
    @EnvironmentObject var lib: LibraryStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 300)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        // 强调色固定在星芒的青绿：点侧栏那个小 C 换彩蛋时，右上角工具栏不会跟着变色
        .tint(BrandVariant.accent)
        .frame(minWidth: 960, minHeight: 600)
        .alert("提示", isPresented: Binding(
            get: { lib.errorMessage != nil },
            set: { if !$0 { lib.errorMessage = nil } }
        )) {
            Button("好") { lib.errorMessage = nil }
        } message: {
            Text(lib.errorMessage ?? "")
        }
        .sheet(item: $lib.depthRequest) { request in
            ScanDepthSheet(volume: request.volume)
                .environmentObject(lib)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            ZStack {
                if lib.volumes.isEmpty {
                    EmptyStateView()
                } else if !lib.searchText.isEmpty {
                    SearchResultsView()
                } else if lib.screen == .pool {
                    PoolView()
                } else {
                    switch lib.viewMode {
                    case .list: FinderListView()
                    case .column: FinderColumnView()
                    case .icon: FinderIconView()
                    }
                }

                if let scan = lib.scanState {
                    ScanOverlay(state: scan)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))

            if !lib.volumes.isEmpty && lib.screen == .browser && lib.searchText.isEmpty {
                Divider()
                PathBarView()
            }
        }
        .navigationTitle(lib.searchText.isEmpty ? lib.currentTitle : "搜索")
        .navigationSubtitle(lib.searchText.isEmpty ? lib.currentSubtitle : "\(lib.searchScopeTitle) · 名称匹配")
        .searchable(text: $lib.searchText, placement: .toolbar, prompt: "搜索名称")
        .inspector(isPresented: $lib.inspectorVisible) {
            InspectorView()
                .inspectorColumnWidth(min: 240, ideal: 268, max: 360)
        }
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            if lib.screen == .browser {
                Button {
                    lib.showPool()
                } label: {
                    Image(systemName: "circle.grid.2x2")
                }
                .help("回到硬盘池")

                Button {
                    lib.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!lib.canGoBack)
                .help("后退（⌘[）")
                .keyboardShortcut("[", modifiers: .command)

                Button {
                    lib.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!lib.canGoForward)
                .help("前进（⌘]）")
                .keyboardShortcut("]", modifiers: .command)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ExportMenu()

            AddDriveMenu()

            if lib.screen == .browser {
                SortMenu()

                Picker("视图", selection: $lib.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Image(systemName: mode.symbol)
                            .help(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 116)

                Button {
                    lib.inspectorVisible.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("显示 / 隐藏简介")
            }
        }
    }
}

// MARK: - 导出 / 导入

struct ExportMenu: View {
    @EnvironmentObject var lib: LibraryStore

    var body: some View {
        Menu {
            Button {
                lib.exportCurrentResults()
            } label: {
                Label("导出当前结果…", systemImage: "tablecells")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(lib.volumes.isEmpty)

            Divider()

            Button {
                lib.exportLibraryPackage()
            } label: {
                Label("导出数据文件（.cyan）…", systemImage: "shippingbox")
            }
            .disabled(lib.volumes.isEmpty)

            Button {
                lib.promptImportPackage()
            } label: {
                Label("导入数据文件…", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
        .help("导出当前清单（Excel / CSV / JSON…），或打包整个索引库")
    }
}

// MARK: - 添加硬盘 + 扫描深度

struct AddDriveMenu: View {
    @EnvironmentObject var lib: LibraryStore

    var body: some View {
        Menu {
            Button {
                lib.chooseVolumesToScan()
            } label: {
                Label("添加硬盘…", systemImage: "plus")
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Menu {
                ForEach(1...8, id: \.self) { depth in
                    Button {
                        lib.defaultDepth = depth
                    } label: {
                        if depth == lib.defaultDepth {
                            Label("\(depth) 级", systemImage: "checkmark")
                        } else {
                            Text("\(depth) 级")
                        }
                    }
                }
            } label: {
                Text("默认扫描深度：\(lib.defaultDepth) 级")
            }
        } label: {
            Label("添加硬盘", systemImage: "plus")
        }
        .help("扫描新硬盘，可选索引深度 1–8 级")
    }
}

// MARK: - 排序菜单

struct SortMenu: View {
    @EnvironmentObject var lib: LibraryStore

    var body: some View {
        Menu {
            ForEach(SortKey.allCases) { key in
                Button {
                    lib.setSort(key)
                } label: {
                    if lib.sortKey == key {
                        Label("\(key.title)（\(lib.sortAscending ? "升序" : "降序")）", systemImage: "checkmark")
                    } else {
                        Text(key.title)
                    }
                }
            }
            Divider()
            Toggle("显示隐藏项目", isOn: $lib.showHidden)
        } label: {
            Label("排序", systemImage: "arrow.up.arrow.down")
        }
        .help("排序与显示")
    }
}

// MARK: - 底部路径栏

struct PathBarView: View {
    @EnvironmentObject var lib: LibraryStore

    private struct Crumb: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let target: [Node]?      // nil 表示这一项不能点（比如选中的是文件）
    }

    /// 面包屑跟随"当前选中层级"：分栏视图里选中的文件夹也算
    private var visibleChain: [Node] {
        lib.viewMode == .column ? lib.path + lib.columnChain : lib.path
    }

    private var crumbs: [Crumb] {
        guard let volume = lib.selectedVolume else { return [] }
        var items: [Crumb] = [
            Crumb(id: "vol-\(volume.id)",
                  name: volume.displayName,
                  icon: IconProvider.shared.sidebarImage(for: volume),
                  target: [])
        ]
        let nodes = visibleChain
        for (index, node) in nodes.enumerated() {
            items.append(Crumb(id: node.id.uuidString,
                               name: node.name,
                               icon: IconProvider.shared.icon(for: node),
                               target: node.isFolder ? Array(nodes.prefix(index + 1)) : nil))
        }
        return items
    }

    var body: some View {
        HStack(spacing: 4) {
            let items = crumbs
            ForEach(Array(items.enumerated()), id: \.element.id) { index, crumb in
                if index > 0 {
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Button {
                    if let target = crumb.target { lib.go(to: target) }
                } label: {
                    HStack(spacing: 4) {
                        if let icon = crumb.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
                        Text(crumb.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(crumb.target == nil)
                .layoutPriority(index == items.count - 1 ? 2 : 1)
                .help(crumb.name)
            }

            Spacer(minLength: 8)

            Text(itemSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
    }

    private var itemSummary: String {
        let folder: Node?
        if lib.viewMode == .column, let last = visibleChain.last, last.isFolder {
            folder = last
        } else {
            folder = lib.currentFolder
        }
        guard let folder else { return "" }
        return "\(Fmt.count(lib.visibleChildren(of: folder).count)) 个项目"
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    @EnvironmentObject var lib: LibraryStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("把硬盘的目录收进来")
                    .font(.system(size: 19, weight: .semibold))
                Text("只记录目录层级和文件名，不复制任何文件；索引深度 \(lib.defaultDepth) 级。之后不插硬盘也能翻。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            Button {
                lib.chooseVolumesToScan()
            } label: {
                Text("选择硬盘开始扫描…")
                    .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            let detected = lib.mountedUnindexed
            if !detected.isEmpty {
                VStack(spacing: 6) {
                    Text("检测到这些硬盘还没建立索引")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(detected, id: \.url.path) { item in
                            Button {
                                lib.startScan(url: item.url)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "externaldrive")
                                    Text(item.name)
                                }
                                .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(40)
    }
}

// MARK: - 扫描进度

struct ScanOverlay: View {
    let state: LibraryStore.ScanState

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在扫描「\(state.name)」")
                .font(.system(size: 13, weight: .medium))
            Text("已读取 \(Fmt.count(state.scanned)) 个项目")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(28)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    }
}

// MARK: - 搜索结果

struct SearchResultsView: View {
    @EnvironmentObject var lib: LibraryStore
    @State private var selected: Node.ID?

    private var hits: [LibraryStore.SearchHit] { lib.search(lib.searchText) }

    private var searchScopeBinding: Binding<LibraryStore.SearchScope> {
        Binding(
            get: { lib.searchScope },
            set: { lib.searchScopeOverride = $0 }
        )
    }

    var body: some View {
        let results = hits
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("搜索结果")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(results.count) 项")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 10)

                Picker("搜索范围", selection: searchScopeBinding) {
                    Text("当前硬盘").tag(LibraryStore.SearchScope.current)
                    Text("全部硬盘").tag(LibraryStore.SearchScope.all)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 150)
                .help(lib.searchScope == .current
                      ? "只搜索「\(lib.searchScopeTitle)」里已索引的内容"
                      : "搜索所有已索引硬盘")
            }
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(Color.primary.opacity(0.04))

            if results.isEmpty {
                VStack(spacing: 8) {
                    Text("没有匹配的项目")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("搜索范围：\(lib.searchScopeTitle)，限已索引的 \(lib.selectedVolume?.maxDepth ?? 3) 级目录")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { hit in
                            SearchResultRow(hit: hit, isSelected: selected == hit.id)
                                .onTapGesture { selected = hit.id }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    lib.jump(to: hit)
                                })
                                .contextMenu {
                                    Button("前往所在位置") { lib.jump(to: hit) }
                                    Button("复制名称") { lib.copyName(hit.node) }
                                }
                        }
                    }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let hit: LibraryStore.SearchHit
    let isSelected: Bool

    private var displayPath: String { hit.displayPath }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: IconProvider.shared.icon(for: hit.node))
                .resizable()
                .frame(width: 16, height: 16)
            Text(hit.node.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            if !hit.displayPath.isEmpty {
                Text(hit.displayPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 8)
            Text(Fmt.size(hit.node))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(isSelected ? Color.accentColor : Color.clear)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .contentShape(Rectangle())
    }
}

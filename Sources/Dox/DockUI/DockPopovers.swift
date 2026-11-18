import SwiftUI
import AppKit
import DoxCore

// MARK: - Category stack popover

/// Grid of a collapsed (`.stack`) category's items.
@MainActor
struct CategoryStackPopover: View {
    let dockID: UUID
    let dock: DockConfig
    let category: DockCategory
    let isPreview: Bool
    @Binding var isPresented: Bool

    @State private var dropTargeted = false

    private var items: [DockItem] { category.items.filter { !$0.kind.isDecorative } }
    private var columns: Int { min(5, max(3, Int(Double(items.count).squareRoot().rounded(.up)))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DockSymbolTile(symbol: category.symbol, tint: category.color, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(SK.items(items.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 20)
                Button {
                    isPresented = false
                    SettingsRouter.shared.editCategory(category.id, dock: dockID)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Upraviť kategóriu")
            }

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color(category.color))
                    Text("Kategória je prázdna.\nPretiahni sem aplikácie, priečinky alebo odkazy.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 8), count: columns),
                          spacing: 10) {
                    ForEach(items) { item in
                        StackPopoverCell(dockID: dockID, dock: dock, item: item, category: category,
                                         isPreview: isPreview, isPresented: $isPresented)
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 280)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(category.color).opacity(dropTargeted ? 0.9 : 0), lineWidth: 2)
                .padding(4)
        }
        .onDrop(of: DockDropHandler.acceptedTypes, isTargeted: $dropTargeted) { providers in
            DockDropHandler.handle(providers, dockID: dockID, categoryID: category.id, index: nil)
        }
        .modifier(DockColorSchemeModifier(mode: dock.appearance.mode))
    }
}

@MainActor
private struct StackPopoverCell: View {
    let dockID: UUID
    let dock: DockConfig
    let item: DockItem
    let category: DockCategory
    let isPreview: Bool
    @Binding var isPresented: Bool

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            DockItemIcon(item: item, size: 48, shape: dock.appearance.iconShape,
                         shadow: dock.appearance.iconShadow, fallbackTint: category.color, renderScale: 1.5)
                .scaleEffect(hovering ? 1.08 : 1)
            Text(item.displayTitle)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
        }
        .frame(width: 80)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.08 : 0))
        )
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hovering = h }
        }
        .onTapGesture {
            guard !isPreview else { return }
            let alternate = NSEvent.modifierFlags.contains(.option)
            ItemLauncher.open(item, behavior: dock.behavior, alternate: alternate)
            isPresented = false
        }
        .contextMenu {
            DockItemMenu(dockID: dockID, dock: dock, item: item, categoryID: category.id, isPreview: isPreview)
        }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .help(item.displayTitle)
    }
}

// MARK: - Folder stack

/// Contents of a folder item as grid, list or fan.
@MainActor
struct FolderStackView: View {
    let item: DockItem
    let dockID: UUID
    let behavior: DockBehavior
    let edge: DockEdge
    let accent: RGBAColor
    @Binding var isPresented: Bool

    @State private var entries: [URL] = []
    @State private var loaded = false

    static let limit = 40
    private static let fanLimit = 12

    private var path: String { item.kind.path ?? NSHomeDirectory() }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            Group {
                if loaded && entries.isEmpty {
                    emptyState
                } else {
                    switch item.folderPresentation {
                    case .grid: grid
                    case .list: list
                    case .fan: fan
                    }
                }
            }
            Divider().opacity(0.6)
            footer
        }
        .frame(width: item.folderPresentation == .grid ? 380 : 300)
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(loaded ? SK.items(entries.count) + (entries.count >= Self.limit ? "+" : "") : " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.folderSort.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var footer: some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            isPresented = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text("Otvoriť vo Finderi")
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(accent))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text("Priečinok je prázdny")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 6), count: 4), spacing: 8) {
                ForEach(entries, id: \.self) { url in
                    FolderEntryCell(url: url, style: .grid) { open(url) }
                }
            }
            .padding(10)
        }
        .frame(height: min(380, CGFloat((entries.count + 3) / 4) * 98 + 20))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(entries, id: \.self) { url in
                    FolderEntryCell(url: url, style: .list) { open(url) }
                }
            }
            .padding(6)
        }
        .frame(height: min(400, CGFloat(entries.count) * 30 + 12))
    }

    /// A gently curved, rotated column of the most relevant entries.
    private var fan: some View {
        let shown = Array(entries.prefix(Self.fanLimit))
        // Bottom docks read best when the nearest entry sits closest to the dock.
        let ordered = edge == .bottom ? Array(shown.reversed()) : shown
        let count = ordered.count
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.element) { index, url in
                let distance = edge == .bottom ? Double(count - 1 - index) : Double(index)
                FolderEntryCell(url: url, style: .fan) { open(url) }
                    .rotationEffect(.degrees(distance * 0.9), anchor: .leading)
                    .offset(x: CGFloat(distance * distance) * 0.55)
            }
            if entries.count > Self.fanLimit {
                Text("a ďalšie…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
            }
        }
        .padding(12)
    }

    // MARK: Actions

    private func load() {
        entries = FolderContents.items(in: path, sort: item.folderSort, limit: Self.limit)
        loaded = true
    }

    private func open(_ url: URL) {
        ItemLauncher.open(url: url)
        isPresented = false
        if behavior.hideAfterLaunch { DockManager.shared.hide(dockID: dockID) }
    }
}

@MainActor
private struct FolderEntryCell: View {
    enum Style { case grid, list, fan }

    let url: URL
    let style: Style
    let action: () -> Void

    @State private var hovering = false

    private var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
    private var name: String { FileManager.default.displayName(atPath: url.path) }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
            .onTapGesture(perform: action)
            .onDrag { NSItemProvider(object: url as NSURL) }
            .contextMenu {
                Button {
                    action()
                } label: {
                    Label("Otvoriť", systemImage: "arrow.up.forward.app")
                }
                Button {
                    ItemLauncher.revealInFinder(url: url)
                } label: {
                    Label("Ukázať vo Finderi", systemImage: "folder")
                }
            }
            .help(name)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .grid:
            VStack(spacing: 4) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .scaleEffect(hovering ? 1.08 : 1)
                Text(name)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28, alignment: .top)
            }
            .frame(width: 76)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        case .list:
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if url.hasDirectoryPath {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        case .fan:
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(hovering ? 0.25 : 0.08), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            .scaleEffect(hovering ? 1.04 : 1, anchor: .leading)
            .frame(maxWidth: 240, alignment: .leading)
        }
    }
}

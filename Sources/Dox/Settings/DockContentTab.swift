import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DoxCore

/// "Obsah" tab: categories (left top), items of the selected category (left bottom), editor (right).
@MainActor
struct DockContentTab: View {
    let dockID: UUID

    @State private var showLinkSheet = false
    @State private var confirmDeleteCategory = false
    @State private var itemsDropTargeted = false

    private var store: DoxStore { DoxStore.shared }
    private var router: SettingsRouter { SettingsRouter.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            let category = currentCategory(in: dock)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    categoriesPanel(dock, selected: category)
                        .frame(minHeight: 170, idealHeight: 210, maxHeight: 260)
                    Divider()
                    itemsPanel(dock, category: category)
                }
                .frame(width: 300)
                .background(Color.primary.opacity(0.025))

                Divider()

                ScrollView {
                    editor(dock, category: category)
                        .padding(DS.Spacing.xl)
                        .frame(maxWidth: 640, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .sheet(isPresented: $showLinkSheet) {
                LinkSheet { item in
                    guard let category else { return }
                    store.updateDock(dockID) { $0.addItem(item, to: category.id) }
                    router.contentItemID = item.id
                }
            }
            .confirmationDialog("Odstrániť kategóriu?", isPresented: $confirmDeleteCategory, titleVisibility: .visible) {
                Button("Odstrániť", role: .destructive) {
                    if let category { deleteCategory(category.id) }
                }
                Button("Zrušiť", role: .cancel) {}
            } message: {
                Text("Kategória „\(category?.name ?? "")“ aj s položkami (\(category?.items.count ?? 0)) bude odstránená z docku.")
            }
        }
    }

    // MARK: Selection

    private func currentCategory(in dock: DockConfig) -> DockCategory? {
        if let id = router.contentCategoryID, let c = dock.categories.first(where: { $0.id == id }) { return c }
        return dock.categories.first
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: {
                guard let dock = DoxStore.shared.dock(dockID) else { return nil }
                return currentCategory(in: dock)?.id
            },
            set: { [router] id in
                guard let id else { return }
                if router.contentCategoryID != id { router.contentItemID = nil }
                router.contentCategoryID = id
            }
        )
    }

    private var itemSelection: Binding<UUID?> {
        Binding(
            get: { [router] in router.contentItemID },
            set: { [router] id in router.contentItemID = id }
        )
    }

    // MARK: Categories panel

    private func categoriesPanel(_ dock: DockConfig, selected: DockCategory?) -> some View {
        VStack(spacing: 0) {
            panelHeader("Kategórie", count: dock.categories.count)
            List(selection: categorySelection) {
                ForEach(dock.categories) { cat in
                    CategoryListRow(category: cat)
                        .tag(cat.id)
                        .contextMenu {
                            Button(cat.isHidden ? "Zobraziť v docku" : "Skryť v docku") {
                                updateCategory(cat.id) { $0.isHidden.toggle() }
                            }
                            Button(cat.display == .stack ? "Rozbaliť do docku" : "Zložiť do jednej ikony") {
                                updateCategory(cat.id) { $0.display = $0.display == .stack ? .inline : .stack }
                            }
                            Divider()
                            Button("Odstrániť…", role: .destructive) {
                                router.contentCategoryID = cat.id
                                confirmDeleteCategory = true
                            }
                        }
                }
                .onMove { from, to in
                    store.updateDock(dockID) { $0.categories.move(fromOffsets: from, toOffset: to) }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            panelFooter {
                Button {
                    addCategory()
                } label: {
                    Image(systemName: "plus").frame(width: 22, height: 20)
                }
                .help("Pridať kategóriu")
                Button {
                    confirmDeleteCategory = true
                } label: {
                    Image(systemName: "minus").frame(width: 22, height: 20)
                }
                .disabled(selected == nil)
                .help("Odstrániť kategóriu")
            }
        }
    }

    // MARK: Items panel

    private func itemsPanel(_ dock: DockConfig, category: DockCategory?) -> some View {
        VStack(spacing: 0) {
            panelHeader(category?.name ?? "Položky", count: category?.items.count ?? 0,
                        color: category?.color)
            if let category {
                if category.items.isEmpty {
                    VStack(spacing: DS.Spacing.s) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(Color(category.color))
                        Text("Pretiahni sem aplikácie, priečinky alebo odkazy, alebo použi tlačidlo +.")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DS.Spacing.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: itemSelection) {
                        ForEach(category.items) { item in
                            ItemListRow(item: item, tint: category.color)
                                .tag(item.id)
                        }
                        .onMove { from, to in
                            store.updateDock(dockID) { d in
                                guard let ci = d.categoryIndex(category.id) else { return }
                                d.categories[ci].items.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            } else {
                Text("Najprv pridaj kategóriu.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            panelFooter {
                Menu {
                    Button {
                        if let category { addFromOpenPanel(to: category.id) }
                    } label: {
                        Label("Aplikácie, súbory alebo priečinky…", systemImage: "plus.app")
                    }
                    Button {
                        showLinkSheet = true
                    } label: {
                        Label("Odkaz…", systemImage: "link")
                    }
                    Divider()
                    Button {
                        if let category { addDecorative(.separator, to: category.id) }
                    } label: {
                        Label("Oddeľovač", systemImage: "line.diagonal")
                    }
                    Button {
                        if let category { addDecorative(.spacer, to: category.id) }
                    } label: {
                        Label("Medzera", systemImage: "arrow.left.and.right")
                    }
                } label: {
                    Image(systemName: "plus").frame(width: 22, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(category == nil)
                .help("Pridať položku")

                Button {
                    if let id = router.contentItemID {
                        store.updateDock(dockID) { $0.removeItem(id) }
                        router.contentItemID = nil
                    }
                } label: {
                    Image(systemName: "minus").frame(width: 22, height: 20)
                }
                .disabled(router.contentItemID == nil)
                .help("Odstrániť položku")
            }
        }
        .overlay {
            if itemsDropTargeted {
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(DS.Color.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL, .url], isTargeted: $itemsDropTargeted) { providers in
            DockDropHandler.handle(providers, dockID: dockID, categoryID: category?.id, index: nil)
        }
    }

    // MARK: Editor

    @ViewBuilder
    private func editor(_ dock: DockConfig, category: DockCategory?) -> some View {
        if let category,
           let itemID = router.contentItemID,
           let item = category.items.first(where: { $0.id == itemID }) {
            ItemEditor(dockID: dockID, item: item, category: category)
                .id(item.id)
        } else if let category {
            CategoryEditor(dockID: dockID, category: category,
                           onDelete: { confirmDeleteCategory = true })
                .id(category.id)
        } else {
            ContentUnavailableView {
                Label("Žiadne kategórie", systemImage: "square.stack.3d.up.slash")
            } description: {
                Text("Kategórie zoskupujú aplikácie, priečinky, súbory a odkazy pod jedným názvom, symbolom a farbou.")
            } actions: {
                Button("Pridať kategóriu") { addCategory() }
            }
            .padding(.top, 40)
        }
    }

    // MARK: Panel chrome

    private func panelHeader(_ title: String, count: Int, color: RGBAColor? = nil) -> some View {
        HStack(spacing: 6) {
            if let color {
                Circle().fill(Color(color)).frame(width: 8, height: 8)
            }
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(DS.Color.secondaryText)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(DS.Font.mono)
                .foregroundStyle(DS.Color.secondaryText)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.xs)
    }

    private func panelFooter<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) {
            content()
            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, 6)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Actions

    private func updateCategory(_ id: UUID, _ change: @escaping (inout DockCategory) -> Void) {
        store.updateDock(dockID) { d in
            if let i = d.categoryIndex(id) { change(&d.categories[i]) }
        }
    }

    private func addCategory() {
        let palette = ["#7C8CFF", "#5EF2C2", "#F5B544", "#FF7A90", "#4FC3F7", "#B388FF", "#9CCC65"]
        let count = store.dock(dockID)?.categories.count ?? 0
        let color = RGBAColor(hex: palette[count % palette.count]) ?? .white
        let category = DockCategory(name: "Nová kategória", symbol: "square.grid.2x2", color: color)
        store.updateDock(dockID) { $0.addCategory(category) }
        router.contentCategoryID = category.id
        router.contentItemID = nil
    }

    private func deleteCategory(_ id: UUID) {
        store.updateDock(dockID) { $0.removeCategory(id) }
        router.contentCategoryID = store.dock(dockID)?.categories.first?.id
        router.contentItemID = nil
    }

    private func addDecorative(_ kind: DockItemKind, to categoryID: UUID) {
        let item = DockItem(kind: kind)
        store.updateDock(dockID) { $0.addItem(item, to: categoryID) }
        router.contentItemID = item.id
    }

    private func addFromOpenPanel(to categoryID: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Pridať"
        panel.message = "Vyber aplikácie, súbory alebo priečinky, ktoré chceš pridať do kategórie."
        guard panel.runModal() == .OK else { return }
        var lastID: UUID?
        for url in panel.urls {
            let item = DockDropHandler.item(for: url)
            store.updateDock(dockID) { $0.addItem(item, to: categoryID) }
            if store.dock(dockID)?.item(item.id) != nil { lastID = item.id }
        }
        if let lastID { router.contentItemID = lastID }
    }
}

// MARK: - Rows

@MainActor
private struct CategoryListRow: View {
    let category: DockCategory

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            DockSymbolTile(symbol: category.symbol, tint: category.color, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.name.isEmpty ? "Bez názvu" : category.name)
                    .lineLimit(1)
                Text(SK.items(category.items.count))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if category.display == .stack {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help("Zložená do jednej ikony")
            }
            if category.isHidden {
                Image(systemName: "eye.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help("Skrytá v docku")
            }
        }
        .padding(.vertical, 2)
        .opacity(category.isHidden ? 0.6 : 1)
    }
}

@MainActor
private struct ItemListRow: View {
    let item: DockItem
    let tint: RGBAColor

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            switch item.kind {
            case .separator:
                Image(systemName: "line.diagonal")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            case .spacer:
                Image(systemName: "arrow.left.and.right")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            default:
                DockItemIcon(item: item, size: 22, fallbackTint: tint, renderScale: 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .lineLimit(1)
                Text(item.kind.typeName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let path = item.kind.path, !FileManager.default.fileExists(atPath: path) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .help("Súbor sa nenašiel")
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Category editor

@MainActor
private struct CategoryEditor: View {
    let dockID: UUID
    let category: DockCategory
    let onDelete: () -> Void

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            HStack(spacing: DS.Spacing.m) {
                DockSymbolTile(symbol: category.symbol, tint: category.color, size: 52)
                    .shadow(color: Color(category.color).opacity(0.4), radius: 10, x: 0, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name.isEmpty ? "Bez názvu" : category.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Kategória · \(SK.items(category.items.count))")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                }
            }

            SettingsSection("Kategória", symbol: "square.stack.3d.up.fill") {
                FieldRow("Názov") {
                    TextField("Názov kategórie", text: binding(\.name))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }
                FieldRow("Symbol") {
                    SymbolPicker(selection: binding(\.symbol))
                }
                ColorRow("Farba", color: binding(\.color))
                PickerRow("Zobrazenie", selection: binding(\.display), options: CategoryDisplay.allCases,
                          style: .segmented) { $0.displayName }
                ToggleRow("Skryť v docku", subtitle: "Kategória ostane uložená, len sa v docku nezobrazí.",
                          isOn: binding(\.isHidden))
            }

            SettingsSection("Akcie", symbol: "bolt.fill") {
                HStack(spacing: DS.Spacing.s) {
                    Button {
                        var copy = category
                        copy.id = UUID()
                        copy.name = category.name + " – kópia"
                        copy.items = category.items.map { var i = $0; i.id = UUID(); return i }
                        let index = (store.dock(dockID)?.categoryIndex(category.id) ?? 0) + 1
                        store.updateDock(dockID) { $0.addCategory(copy, at: index) }
                        SettingsRouter.shared.contentCategoryID = copy.id
                    } label: {
                        Label("Duplikovať", systemImage: "plus.square.on.square")
                    }
                    .buttonStyle(SoftButtonStyle())

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Odstrániť kategóriu", systemImage: "trash")
                    }
                    .buttonStyle(SoftButtonStyle(destructive: true))
                }
            }
        }
    }

    private func binding<T: Equatable>(_ keyPath: WritableKeyPath<DockCategory, T>) -> Binding<T> {
        let fallback = category[keyPath: keyPath]
        let id = category.id
        let dockID = dockID
        return Binding(
            get: {
                DoxStore.shared.dock(dockID)?.categories.first { $0.id == id }?[keyPath: keyPath] ?? fallback
            },
            set: { value in
                DoxStore.shared.updateDock(dockID) { d in
                    if let i = d.categoryIndex(id) { d.categories[i][keyPath: keyPath] = value }
                }
            }
        )
    }
}

// MARK: - Item editor

@MainActor
private struct ItemEditor: View {
    let dockID: UUID
    let item: DockItem
    let category: DockCategory

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            header

            if item.kind.isDecorative {
                SettingsSection("Dekoratívny prvok", symbol: "line.diagonal") {
                    SettingsCaption(item.kind == .separator
                                    ? "Oddeľovač vizuálne rozdelí ikony v rámci kategórie."
                                    : "Medzera vytvorí prázdne miesto veľkosti jednej ikony.")
                    categoryPicker
                }
            } else {
                SettingsSection("Položka", symbol: "square.and.pencil") {
                    FieldRow("Vlastný názov") {
                        TextField(defaultTitle, text: titleBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                    if item.kind.linkURL != nil {
                        FieldRow("Adresa") {
                            TextField("https://", text: linkBinding)
                                .textFieldStyle(.roundedBorder)
                                .font(DS.Font.mono)
                                .frame(maxWidth: 320)
                        }
                    }
                    categoryPicker
                }

                SettingsSection("Ikona", symbol: "app.badge.fill") {
                    ToggleRow("Vlastný symbol",
                              subtitle: "Namiesto ikony súboru zobrazí SF Symbol na farebnej dlaždici.",
                              isOn: customSymbolEnabled)
                    if item.customSymbol != nil {
                        FieldRow("Symbol") {
                            SymbolPicker(selection: symbolBinding)
                        }
                    }
                    OptionalColorRow("Farba dlaždice", color: binding(\.tint), defaultColor: category.color)
                    SettingsCaption("Farba sa použije pre symboly a odkazy. Bez nastavenia preberie farbu kategórie.")
                }

                if case .folder = item.kind {
                    SettingsSection("Priečinok", symbol: "folder.fill") {
                        PickerRow("Zobrazenie", selection: binding(\.folderPresentation),
                                  options: FolderPresentation.allCases, style: .segmented) { $0.displayName }
                        PickerRow("Zoradiť podľa", selection: binding(\.folderSort),
                                  options: FolderSort.allCases) { $0.displayName }
                        SettingsCaption("Kliknutie zobrazí až \(FolderStackView.limit) položiek priečinka. ⌥-klik ho otvorí vo Finderi.")
                    }
                }
            }

            HStack(spacing: DS.Spacing.s) {
                if !item.kind.isDecorative {
                    Button {
                        if let dock = store.dock(dockID) {
                            ItemLauncher.open(item, behavior: dock.behavior, alternate: false)
                        }
                    } label: {
                        Label("Otvoriť", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                if item.kind.path != nil {
                    Button {
                        ItemLauncher.revealInFinder(item)
                    } label: {
                        Label("Ukázať vo Finderi", systemImage: "folder")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Spacer()
                Button(role: .destructive) {
                    store.updateDock(dockID) { $0.removeItem(item.id) }
                    SettingsRouter.shared.contentItemID = nil
                } label: {
                    Label("Odstrániť z docku", systemImage: "trash")
                }
                .buttonStyle(SoftButtonStyle(destructive: true))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Group {
                if item.kind.isDecorative {
                    Image(systemName: item.kind == .separator ? "line.diagonal" : "arrow.left.and.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.Color.secondaryText)
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.Color.cardBackground))
                } else {
                    DockItemIcon(item: item, size: 56, shadow: true, fallbackTint: category.color, renderScale: 2)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.kind.typeName)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(category.color).opacity(0.2)))
                    Text(category.name)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                }
                if let location = item.kind.path ?? item.kind.linkURL {
                    Text(location)
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Color.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(location)
                }
            }
        }
    }

    private var categoryPicker: some View {
        let categories = store.dock(dockID)?.categories ?? []
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let itemID = item.id
        let dockID = dockID
        return PickerRow("Kategória",
                         selection: Binding(
                            get: { category.id },
                            set: { target in
                                DoxStore.shared.updateDock(dockID) { d in
                                    let count = d.categories.first { $0.id == target }?.items.count ?? 0
                                    d.moveItem(itemID, toCategory: target, at: count)
                                }
                                SettingsRouter.shared.contentCategoryID = target
                                SettingsRouter.shared.contentItemID = itemID
                            }),
                         options: categories.map(\.id)) { names[$0] ?? "" }
    }

    // MARK: Bindings

    private var defaultTitle: String {
        var plain = item
        plain.customTitle = nil
        return plain.displayTitle
    }

    private func binding<T: Equatable>(_ keyPath: WritableKeyPath<DockItem, T>) -> Binding<T> {
        let fallback = item
        let id = item.id
        let dockID = dockID
        return Binding(
            get: { (DoxStore.shared.dock(dockID)?.item(id) ?? fallback)[keyPath: keyPath] },
            set: { value in
                DoxStore.shared.updateDock(dockID) { d in
                    guard var updated = d.item(id) else { return }
                    updated[keyPath: keyPath] = value
                    d.updateItem(updated)
                }
            }
        )
    }

    private var titleBinding: Binding<String> {
        let b = binding(\.customTitle)
        return Binding(get: { b.wrappedValue ?? "" },
                       set: { b.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private var linkBinding: Binding<String> {
        let b = binding(\.kind)
        return Binding(get: { b.wrappedValue.linkURL ?? "" },
                       set: { b.wrappedValue = .link(url: $0.trimmingCharacters(in: .whitespaces)) })
    }

    private var customSymbolEnabled: Binding<Bool> {
        let b = binding(\.customSymbol)
        let fallback = item.kind.linkURL != nil ? "globe" : "star.fill"
        return Binding(get: { b.wrappedValue != nil },
                       set: { b.wrappedValue = $0 ? (b.wrappedValue ?? fallback) : nil })
    }

    private var symbolBinding: Binding<String> {
        let b = binding(\.customSymbol)
        return Binding(get: { b.wrappedValue ?? "star.fill" },
                       set: { b.wrappedValue = $0 })
    }
}

// MARK: - Link sheet

@MainActor
struct LinkSheet: View {
    let onAdd: (DockItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var title = ""
    @State private var symbol = "globe"

    private var normalizedURL: URL? {
        var s = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") && !s.lowercased().hasPrefix("mailto:") { s = "https://" + s }
        guard let url = URL(string: s), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        if scheme == "http" || scheme == "https" { return url.host == nil ? nil : url }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(spacing: DS.Spacing.m) {
                DockSymbolTile(symbol: symbol, tint: RGBAColor(hex: "#4FC3F7") ?? .white, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pridať odkaz")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("Webová stránka alebo ľubovoľná URL schéma (mailto:, slack:, …)")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                FieldRow("Adresa") {
                    TextField("https://priklad.sk", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .font(DS.Font.mono)
                }
                FieldRow("Názov") {
                    TextField("Voliteľný", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("Symbol") {
                    SymbolPicker(selection: $symbol)
                }
            }
            .padding(DS.Spacing.m)
            .background(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous).fill(DS.Color.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(DS.Color.cardBorder, lineWidth: 1))

            if !urlText.isEmpty && normalizedURL == nil {
                SettingsCaption("Adresa nie je platná.", symbol: "exclamationmark.triangle.fill")
            }

            HStack {
                Spacer()
                Button("Zrušiť") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Pridať") {
                    guard let url = normalizedURL else { return }
                    let t = title.trimmingCharacters(in: .whitespaces)
                    onAdd(DockItem(kind: .link(url: url.absoluteString),
                                   customTitle: t.isEmpty ? nil : t,
                                   customSymbol: symbol))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedURL == nil)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 480)
    }
}

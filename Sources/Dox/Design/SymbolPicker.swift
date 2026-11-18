import SwiftUI
import AppKit

/// Button showing the current SF Symbol; opens a popover with a curated,
/// searchable grid. Any valid SF Symbol name can be typed and used.
struct SymbolPicker: View {
    @Binding var selection: String
    @State private var isPresented = false

    init(selection: Binding<String>) {
        self._selection = selection
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: SymbolCatalog.isValid(selection) ? selection : "questionmark.square.dashed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.Color.accent)
                    .frame(width: 28, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                            .fill(DS.Color.readoutBackground)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DS.Color.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Vybrať symbol")
        .accessibilityLabel("Symbol")
        .accessibilityValue(selection)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SymbolPickerPanel(selection: $selection, isPresented: $isPresented)
        }
    }
}

/// Popover content: search field + grouped grid.
struct SymbolPickerPanel: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 34, maximum: 34), spacing: 6)]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredGroups: [SymbolCatalog.SymbolGroup] {
        let q = trimmedQuery
        guard !q.isEmpty else { return SymbolCatalog.groups }
        return SymbolCatalog.groups.compactMap { group in
            if group.title.localizedStandardContains(q) { return group }
            let hits = group.symbols.filter { $0.localizedStandardContains(q) }
            return hits.isEmpty ? nil : SymbolCatalog.SymbolGroup(title: group.title, symbols: hits)
        }
    }

    /// The typed text, when it names a real SF Symbol that is not already in the grid.
    private var customCandidate: String? {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty, SymbolCatalog.isValid(q), !SymbolCatalog.all.contains(q) else { return nil }
        return q
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Color.secondaryText)
                TextField("Hľadať alebo zadať názov symbolu", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit(submit)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Color.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Vymazať hľadanie")
                }
            }
            .font(DS.Font.rowTitle)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s + 2, style: .continuous)
                    .fill(DS.Color.readoutBackground)
            )

            if let custom = customCandidate {
                Button {
                    choose(custom)
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        Image(systemName: custom)
                            .frame(width: 22)
                        Text("Použiť „\(custom)“")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "return")
                            .foregroundStyle(DS.Color.secondaryText)
                    }
                    .font(DS.Font.rowTitle)
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                            .fill(DS.Color.accent.opacity(0.14))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.m) {
                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(group.title)
                                .font(DS.Font.caption.weight(.semibold))
                                .foregroundStyle(DS.Color.secondaryText)
                                .textCase(.uppercase)
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                                ForEach(group.symbols, id: \.self) { name in
                                    SymbolCell(name: name, isSelected: name == selection) {
                                        choose(name)
                                    }
                                }
                            }
                        }
                    }
                    if filteredGroups.isEmpty && customCandidate == nil {
                        Text("Nič sa nenašlo. Zadajte presný názov SF Symbolu.")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.Spacing.xl)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.m)
        .frame(width: 340, height: 380)
    }

    private func submit() {
        if let custom = customCandidate {
            choose(custom)
        } else if let first = filteredGroups.first?.symbols.first {
            choose(first)
        }
    }

    private func choose(_ name: String) {
        selection = name
        isPresented = false
    }
}

private struct SymbolCell: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15))
                .frame(width: 34, height: 30)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(isSelected ? DS.Color.accent
                                         : (hovering ? DS.Color.readoutBackground : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Curated SF Symbols for categories and items (all available on macOS 14).
enum SymbolCatalog {
    struct SymbolGroup: Identifiable {
        let title: String
        let symbols: [String]
        var id: String { title }
    }

    static let groups: [SymbolGroup] = [
        SymbolGroup(title: "Práca", symbols: [
            "briefcase.fill", "calendar", "checklist", "list.bullet.rectangle", "chart.bar.fill",
            "chart.pie.fill", "doc.text.fill", "tray.full.fill", "clock.fill", "building.2.fill",
        ]),
        SymbolGroup(title: "Súbory", symbols: [
            "folder.fill", "folder.badge.plus", "archivebox.fill", "externaldrive.fill", "internaldrive.fill",
            "icloud.fill", "doc.on.doc.fill", "paperclip", "tray.and.arrow.down.fill", "shippingbox.fill",
        ]),
        SymbolGroup(title: "Web", symbols: [
            "globe", "safari.fill", "link", "network", "wifi",
            "bookmark.fill", "star.fill", "newspaper.fill", "cloud.fill", "magnifyingglass",
        ]),
        SymbolGroup(title: "Vývoj", symbols: [
            "chevron.left.forwardslash.chevron.right", "terminal.fill", "hammer.fill",
            "wrench.and.screwdriver.fill", "curlybraces", "cpu.fill", "server.rack", "ladybug.fill",
            "gearshape.2.fill", "square.stack.3d.up.fill",
        ]),
        SymbolGroup(title: "Médiá", symbols: [
            "music.note", "play.rectangle.fill", "film.fill", "headphones", "photo.fill",
            "camera.fill", "mic.fill", "tv.fill", "radio.fill", "waveform",
        ]),
        SymbolGroup(title: "Dizajn", symbols: [
            "paintbrush.fill", "paintpalette.fill", "pencil.and.ruler.fill", "scribble.variable",
            "wand.and.stars", "eyedropper.halffull", "cube.fill", "square.on.circle", "crop", "sparkles",
        ]),
        SymbolGroup(title: "Komunikácia", symbols: [
            "message.fill", "bubble.left.and.bubble.right.fill", "envelope.fill", "phone.fill", "video.fill",
            "person.2.fill", "at", "paperplane.fill", "bell.fill", "megaphone.fill",
        ]),
        SymbolGroup(title: "Hry", symbols: [
            "gamecontroller.fill", "dice.fill", "puzzlepiece.fill", "trophy.fill", "flag.checkered",
            "target", "suit.spade.fill", "crown.fill",
        ]),
        SymbolGroup(title: "Ostatné", symbols: [
            "house.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "book.fill",
            "graduationcap.fill", "cart.fill", "creditcard.fill", "lock.fill", "gearshape.fill", "lightbulb.fill",
        ]),
    ]

    static let all: [String] = groups.flatMap(\.symbols)

    static func isValid(_ name: String) -> Bool {
        !name.isEmpty && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}

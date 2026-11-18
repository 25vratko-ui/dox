import SwiftUI
import Observation
import DoxCore

/// Sidebar pages of the settings window.
enum SettingsPage: Hashable {
    case dock(UUID)
    case themes
    case shortcuts
    case general
}

/// Tabs of a dock's detail page.
enum DockSettingsTab: String, CaseIterable, Identifiable {
    case content, appearance, layout, behavior, shortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .content: "Obsah"
        case .appearance: "Vzhľad"
        case .layout: "Rozloženie"
        case .behavior: "Správanie"
        case .shortcut: "Skratka"
        }
    }

    var symbol: String {
        switch self {
        case .content: "square.stack.3d.up.fill"
        case .appearance: "paintbrush.fill"
        case .layout: "rectangle.3.group.fill"
        case .behavior: "hand.tap.fill"
        case .shortcut: "command"
        }
    }
}

/// Navigation state of the settings window. The dock UI uses it for "Upraviť…".
@MainActor
@Observable
final class SettingsRouter {
    static let shared = SettingsRouter()

    var page: SettingsPage?
    var dockTab: DockSettingsTab = .content
    /// Category whose items are listed in the Obsah tab.
    var contentCategoryID: UUID?
    /// Item open in the editor (nil → the category editor is shown).
    var contentItemID: UUID?

    private init() {}

    /// Opens settings on a dock's page.
    func openDock(_ dockID: UUID, tab: DockSettingsTab? = nil) {
        DoxStore.shared.selectedDockID = dockID
        page = .dock(dockID)
        if let tab { dockTab = tab }
        SettingsWindowController.shared.show()
    }

    /// Opens settings with an item selected in the content editor.
    func editItem(_ itemID: UUID, category categoryID: UUID, dock dockID: UUID) {
        contentCategoryID = categoryID
        contentItemID = itemID
        openDock(dockID, tab: .content)
    }

    /// Opens settings with a category selected in the content editor.
    func editCategory(_ categoryID: UUID, dock dockID: UUID) {
        contentCategoryID = categoryID
        contentItemID = nil
        openDock(dockID, tab: .content)
    }
}

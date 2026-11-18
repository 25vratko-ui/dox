import XCTest
@testable import DoxCore

final class ShortcutConflictTests: XCTestCase {
    private let cmdOptD = KeyShortcut(keyCode: 2, modifiers: [.command, .option], keyLabel: "D")
    private let cmdComma = KeyShortcut(keyCode: 43, modifiers: [.command], keyLabel: ",")
    private let ctrlSpace = KeyShortcut(keyCode: 49, modifiers: [.control], keyLabel: "Space")

    private func makeConfig() -> (AppConfig, work: DockConfig, media: DockConfig, other: DockConfig) {
        let work = DockConfig(name: "Práca", shortcut: cmdOptD)
        let media = DockConfig(name: "Médiá", shortcut: cmdOptD)
        let other = DockConfig(name: "Iné", shortcut: ctrlSpace)
        let noShortcut = DockConfig(name: "Bez skratky")
        let config = AppConfig(docks: [work, media, other, noShortcut],
                               toggleAllShortcut: cmdOptD,
                               settingsShortcut: cmdComma)
        return (config, work, media, other)
    }

    func testListsEveryUserOfTheShortcutInOrder() {
        let (config, _, _, _) = makeConfig()
        XCTAssertEqual(config.shortcutConflicts(for: cmdOptD),
                       ["Zobraziť/skryť všetky docky", "Práca", "Médiá"])
    }

    func testExcludingADock() {
        let (config, work, _, _) = makeConfig()
        XCTAssertEqual(config.shortcutConflicts(for: cmdOptD, excludingDock: work.id),
                       ["Zobraziť/skryť všetky docky", "Médiá"])
    }

    func testSettingsShortcutConflict() {
        let (config, _, _, _) = makeConfig()
        XCTAssertEqual(config.shortcutConflicts(for: cmdComma), ["Nastavenia"])
    }

    func testDockShortcutConflictOnly() {
        let (config, _, _, other) = makeConfig()
        XCTAssertEqual(config.shortcutConflicts(for: ctrlSpace), ["Iné"])
        XCTAssertEqual(config.shortcutConflicts(for: ctrlSpace, excludingDock: other.id), [])
    }

    func testNoConflicts() {
        let (config, _, _, _) = makeConfig()
        let free = KeyShortcut(keyCode: 2, modifiers: [.command, .shift], keyLabel: "D")
        XCTAssertEqual(config.shortcutConflicts(for: free), [])
        XCTAssertEqual(AppConfig().shortcutConflicts(for: cmdOptD), [])
    }

    func testDockIndex() {
        let (config, _, media, _) = makeConfig()
        XCTAssertEqual(config.dockIndex(media.id), 1)
        XCTAssertNil(config.dockIndex(UUID()))
    }
}

final class BuiltInThemesTests: XCTestCase {
    func testThereAreSevenThemes() {
        XCTAssertEqual(BuiltInThemes.all.count, 7)
    }

    func testIdsAreUniqueAndStable() {
        let ids = BuiltInThemes.all.map(\.id)
        XCTAssertEqual(Set(ids).count, 7)
        let expected = (1...7).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012ld", $0))! }
        XCTAssertEqual(ids, expected)
        // Computed presets return the same id on every access.
        XCTAssertEqual(BuiltInThemes.obsidian.id, BuiltInThemes.obsidian.id)
        XCTAssertEqual(BuiltInThemes.midnight.id, UUID(uuidString: "00000000-0000-0000-0000-000000000007"))
    }

    func testNamesAreUniqueAndNonEmpty() {
        let names = BuiltInThemes.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        XCTAssertEqual(names, ["Obsidián", "Mráz", "Polárna žiara", "Grafit", "Žeravé uhlíky", "Papier", "Polnočný neón"])
    }

    func testAllAreMarkedBuiltIn() {
        XCTAssertTrue(BuiltInThemes.all.allSatisfy(\.isBuiltIn))
    }

    func testAllAppearancesAreAlreadySanitized() {
        for theme in BuiltInThemes.all {
            XCTAssertEqual(theme.appearance, theme.appearance.sanitized(), theme.name)
        }
    }

    func testApplyWithoutKeepSizingReturnsThemeAppearance() {
        var current = DockAppearance()
        current.iconSize = 90
        let result = BuiltInThemes.paper.apply(to: current, keepSizing: false)
        XCTAssertEqual(result, BuiltInThemes.paper.appearance)
    }

    func testApplyKeepSizingKeepsUserSizing() {
        var current = DockAppearance()
        current.iconSize = 80
        current.iconSpacing = 12
        current.padding = 4
        current.magnification = 2.2
        current.magnificationSpread = 4
        current.labelMode = .always
        current.labelFontSize = 15
        current.cornerRadius = 3
        current.material = .menu

        let theme = BuiltInThemes.midnight
        let result = theme.apply(to: current, keepSizing: true)

        // Sizing comes from the user.
        XCTAssertEqual(result.iconSize, 80)
        XCTAssertEqual(result.iconSpacing, 12)
        XCTAssertEqual(result.padding, 4)
        XCTAssertEqual(result.magnification, 2.2)
        XCTAssertEqual(result.magnificationSpread, 4)
        XCTAssertEqual(result.labelMode, .always)
        XCTAssertEqual(result.labelFontSize, 15)

        // The look comes from the theme.
        XCTAssertEqual(result.material, theme.appearance.material)
        XCTAssertEqual(result.tint, theme.appearance.tint)
        XCTAssertEqual(result.tintOpacity, theme.appearance.tintOpacity)
        XCTAssertEqual(result.accent, theme.appearance.accent)
        XCTAssertEqual(result.cornerRadius, theme.appearance.cornerRadius)
        XCTAssertEqual(result.borderColor, theme.appearance.borderColor)
        XCTAssertEqual(result.borderWidth, theme.appearance.borderWidth)
        XCTAssertEqual(result.iconShape, theme.appearance.iconShape)
        XCTAssertEqual(result.hoverEffect, theme.appearance.hoverEffect)
        XCTAssertEqual(result.runningIndicator, theme.appearance.runningIndicator)

        // Exactly the sizing fields differ from the theme.
        var expected = theme.appearance
        expected.iconSize = 80
        expected.iconSpacing = 12
        expected.padding = 4
        expected.magnification = 2.2
        expected.magnificationSpread = 4
        expected.labelMode = .always
        expected.labelFontSize = 15
        XCTAssertEqual(result, expected)
    }
}

final class StarterConfigTests: XCTestCase {
    func testStarterBuildsOneDockWithFourCategories() throws {
        let home = "/Users/tester"
        let config = AppConfig.starter(homeDirectory: home)

        XCTAssertEqual(config.version, AppConfig.currentVersion)
        XCTAssertEqual(config.docks.count, 1)
        let dock = try XCTUnwrap(config.docks.first)
        XCTAssertEqual(dock.name, "Hlavný dock")
        XCTAssertEqual(dock.edge, .left)
        XCTAssertTrue(dock.isEnabled)
        XCTAssertEqual(dock.appearance, BuiltInThemes.obsidian.appearance)
        XCTAssertEqual(dock.categories.map(\.name), ["Práca", "Súbory", "Web", "Nástroje"])
        XCTAssertEqual(dock.categories.map(\.items.count), [3, 3, 2, 3])
        XCTAssertEqual(dock.categories.map(\.display), [.inline, .inline, .inline, .stack])
        XCTAssertEqual(dock.visibleTileCount, 3 + 3 + 2 + 1)
    }

    func testStarterFolderPathsLiveUnderTheGivenHome() throws {
        let home = "/Users/tester"
        let dock = try XCTUnwrap(AppConfig.starter(homeDirectory: home).docks.first)
        let files = dock.categories[1]
        XCTAssertEqual(files.items.map(\.kind), [
            .folder(path: "/Users/tester/Downloads"),
            .folder(path: "/Users/tester/Documents"),
            .folder(path: "/Users/tester/Desktop"),
        ])
        XCTAssertEqual(files.items[0].folderPresentation, .fan)
        XCTAssertEqual(files.items[0].folderSort, .dateAdded)

        // Every user-specific path is under the home folder; nothing references another home.
        let userPaths = dock.categories.flatMap(\.items).compactMap(\.kind.path).filter { $0.hasPrefix("/Users/") }
        XCTAssertEqual(userPaths.count, 3)
        XCTAssertTrue(userPaths.allSatisfy { $0.hasPrefix(home + "/") })
    }

    func testStarterHasUniqueIdsAndNoDuplicates() throws {
        let dock = try XCTUnwrap(AppConfig.starter(homeDirectory: "/Users/x").docks.first)
        let ids = dock.categories.map(\.id) + dock.categories.flatMap(\.items).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for c in dock.categories {
            let keys = c.items.map(\.kind.identityKey)
            XCTAssertEqual(Set(keys).count, keys.count, c.name)
        }
    }

    func testStarterSafeDefaults() {
        let config = AppConfig.starter(homeDirectory: "/Users/x")
        XCTAssertFalse(config.launchAtLogin)
        XCTAssertTrue(config.showMenuBarIcon)
        XCTAssertTrue(config.customThemes.isEmpty)
        XCTAssertNil(config.toggleAllShortcut)
        XCTAssertNil(config.settingsShortcut)
        XCTAssertNil(config.docks.first?.shortcut)
    }
}

import XCTest
@testable import DoxCore

/// Config files must survive app upgrades (new keys) and downgrades (unknown keys).
final class DockAppearanceCodableTests: XCTestCase {
    func testEmptyObjectDecodesToDefaults() throws {
        let a = try Fixtures.decode(DockAppearance.self, json: "{}")
        XCTAssertEqual(a, DockAppearance())
        XCTAssertNil(a.gradientEnd)
        XCTAssertEqual(a.iconSize, 48)
        XCTAssertEqual(a.material, .hud)
    }

    func testUnknownKeysAreIgnoredAndMissingKeysDefault() throws {
        let json = """
        {
          "iconSize": 64,
          "material": "solid",
          "gradientEnd": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
          "someFutureSetting": {"nested": [1, 2, 3]},
          "anotherOne": "hello"
        }
        """
        let a = try Fixtures.decode(DockAppearance.self, json: json)
        var expected = DockAppearance()
        expected.iconSize = 64
        expected.material = .solid
        expected.gradientEnd = RGBAColor(red: 1, green: 0, blue: 0)
        XCTAssertEqual(a, expected)
    }

    func testMalformedValuesFallBackToDefaults() throws {
        let json = #"{"iconSize": "huge", "material": "plasma", "hoverEffect": 3, "padding": 4}"#
        let a = try Fixtures.decode(DockAppearance.self, json: json)
        let d = DockAppearance()
        XCTAssertEqual(a.iconSize, d.iconSize)
        XCTAssertEqual(a.material, d.material)
        XCTAssertEqual(a.hoverEffect, d.hoverEffect)
        XCTAssertEqual(a.padding, 4)
    }

    func testRoundTripPreservesEveryField() throws {
        var a = DockAppearance()
        a.mode = .dark
        a.material = .popover
        a.tint = RGBAColor(hex: "#102030")!
        a.tintOpacity = 0.7
        a.backgroundOpacity = 0.9
        a.gradientEnd = RGBAColor(hex: "#405060")!
        a.accent = RGBAColor(hex: "#FF0000")!
        a.iconSize = 60
        a.iconSpacing = 4
        a.iconShape = .circle
        a.iconShadow = false
        a.padding = 12
        a.cornerRadius = 30
        a.borderWidth = 2
        a.borderColor = RGBAColor(hex: "#00FF0080")!
        a.shadowRadius = 10
        a.shadowOpacity = 0.2
        a.hoverEffect = .glow
        a.magnification = 2.25
        a.magnificationSpread = 3
        a.labelMode = .always
        a.labelFontSize = 14
        a.categoryHeaderStyle = .label
        a.categorySpacing = 20
        a.runningIndicator = .bar
        a.animationSpeed = 0.5
        XCTAssertEqual(try Fixtures.roundTrip(a), a)
    }

    func testSanitizedClampsEveryFieldAboveRange() {
        var a = DockAppearance()
        a.tintOpacity = 2
        a.backgroundOpacity = 5
        a.iconSize = 500
        a.iconSpacing = 100
        a.padding = 100
        a.cornerRadius = 100
        a.borderWidth = 10
        a.shadowRadius = 100
        a.shadowOpacity = 3
        a.magnification = 9
        a.magnificationSpread = 10
        a.labelFontSize = 50
        a.categorySpacing = 100
        a.animationSpeed = 9

        let s = a.sanitized()
        XCTAssertEqual(s.tintOpacity, 1)
        XCTAssertEqual(s.backgroundOpacity, 1)
        XCTAssertEqual(s.iconSize, 128)
        XCTAssertEqual(s.iconSpacing, 40)
        XCTAssertEqual(s.padding, 40)
        XCTAssertEqual(s.cornerRadius, 60)
        XCTAssertEqual(s.borderWidth, 6)
        XCTAssertEqual(s.shadowRadius, 60)
        XCTAssertEqual(s.shadowOpacity, 1)
        XCTAssertEqual(s.magnification, 3)
        XCTAssertEqual(s.magnificationSpread, 6)
        XCTAssertEqual(s.labelFontSize, 20)
        XCTAssertEqual(s.categorySpacing, 48)
        XCTAssertEqual(s.animationSpeed, 3)
    }

    func testSanitizedClampsEveryFieldBelowRange() {
        var a = DockAppearance()
        a.tintOpacity = -1
        a.backgroundOpacity = -1
        a.iconSize = 1
        a.iconSpacing = -5
        a.padding = -5
        a.cornerRadius = -5
        a.borderWidth = -1
        a.shadowRadius = -3
        a.shadowOpacity = -0.5
        a.magnification = 0.5
        a.magnificationSpread = 0
        a.labelFontSize = 2
        a.categorySpacing = -10
        a.animationSpeed = -1

        let s = a.sanitized()
        XCTAssertEqual(s.tintOpacity, 0)
        XCTAssertEqual(s.backgroundOpacity, 0)
        XCTAssertEqual(s.iconSize, 16)
        XCTAssertEqual(s.iconSpacing, 0)
        XCTAssertEqual(s.padding, 0)
        XCTAssertEqual(s.cornerRadius, 0)
        XCTAssertEqual(s.borderWidth, 0)
        XCTAssertEqual(s.shadowRadius, 0)
        XCTAssertEqual(s.shadowOpacity, 0)
        XCTAssertEqual(s.magnification, 1)
        XCTAssertEqual(s.magnificationSpread, 1)
        XCTAssertEqual(s.labelFontSize, 9)
        XCTAssertEqual(s.categorySpacing, 0)
        XCTAssertEqual(s.animationSpeed, 0)
    }

    func testSanitizedKeepsInRangeValuesAndNonNumericFields() {
        XCTAssertEqual(DockAppearance().sanitized(), DockAppearance())

        var a = DockAppearance()
        a.mode = .light
        a.material = .clear
        a.iconShape = .squircle
        a.iconSize = 72
        a.magnification = 2
        XCTAssertEqual(a.sanitized(), a)
    }

    func testDefaultsAreWithinTheirRanges() {
        let d = DockAppearance()
        XCTAssertTrue(DockAppearance.iconSizeRange.contains(d.iconSize))
        XCTAssertTrue(DockAppearance.spacingRange.contains(d.iconSpacing))
        XCTAssertTrue(DockAppearance.paddingRange.contains(d.padding))
        XCTAssertTrue(DockAppearance.cornerRadiusRange.contains(d.cornerRadius))
        XCTAssertTrue(DockAppearance.borderWidthRange.contains(d.borderWidth))
        XCTAssertTrue(DockAppearance.shadowRadiusRange.contains(d.shadowRadius))
        XCTAssertTrue(DockAppearance.magnificationRange.contains(d.magnification))
        XCTAssertTrue(DockAppearance.magnificationSpreadRange.contains(d.magnificationSpread))
        XCTAssertTrue(DockAppearance.labelFontSizeRange.contains(d.labelFontSize))
        XCTAssertTrue(DockAppearance.categorySpacingRange.contains(d.categorySpacing))
        XCTAssertTrue(DockAppearance.animationSpeedRange.contains(d.animationSpeed))
    }
}

final class DockBehaviorCodableTests: XCTestCase {
    func testEmptyObjectDecodesToDefaults() throws {
        let b = try Fixtures.decode(DockBehavior.self, json: "{}")
        XCTAssertEqual(b, DockBehavior())
        XCTAssertEqual(b.display, .main)
        XCTAssertEqual(b.alignment, .center)
        XCTAssertEqual(b.edgeInset, 8)
    }

    func testUnknownKeysAreIgnoredAndMissingKeysDefault() throws {
        let json = """
        {"autoHide": "auto", "edgeInset": 20, "alignment": "trailing",
         "magicFeature": true, "legacyThing": [1, 2]}
        """
        let b = try Fixtures.decode(DockBehavior.self, json: json)
        var expected = DockBehavior()
        expected.autoHide = .auto
        expected.edgeInset = 20
        expected.alignment = .trailing
        XCTAssertEqual(b, expected)
    }

    func testMalformedValuesFallBackToDefaults() throws {
        let b = try Fixtures.decode(DockBehavior.self,
                                    json: #"{"autoHide": "sometimes", "hideDelay": "slow", "display": 42}"#)
        XCTAssertEqual(b, DockBehavior())
    }

    func testRoundTripIncludingDisplayTargets() throws {
        for target in [DisplayTarget.main, .withMouse, .all, .named("LG UltraFine")] {
            var b = DockBehavior()
            b.autoHide = .manual
            b.hideDelay = 1.25
            b.revealDelay = 0.5
            b.alwaysOnTop = false
            b.showOnAllSpaces = false
            b.hideInFullScreen = false
            b.display = target
            b.alignment = .leading
            b.alignmentOffset = -0.25
            b.edgeInset = 0
            b.clickAction = .revealInFinder
            b.hideAfterLaunch = true
            b.showRunningApps = false
            XCTAssertEqual(try Fixtures.roundTrip(b), b, "\(target)")
        }
    }
}

final class DockConfigCodableTests: XCTestCase {
    func testEmptyObjectDecodesToDefaults() throws {
        let d = try Fixtures.decode(DockConfig.self, json: "{}")
        XCTAssertEqual(d.name, "Dock")
        XCTAssertTrue(d.isEnabled)
        XCTAssertEqual(d.edge, .left)
        XCTAssertEqual(d.layout, .line)
        XCTAssertEqual(d.gridLines, 2)
        XCTAssertEqual(d.appearance, DockAppearance())
        XCTAssertEqual(d.behavior, DockBehavior())
        XCTAssertTrue(d.categories.isEmpty)
        XCTAssertNil(d.shortcut)
    }

    func testMissingIdGetsAFreshOneEachTime() throws {
        let a = try Fixtures.decode(DockConfig.self, json: "{}")
        let b = try Fixtures.decode(DockConfig.self, json: "{}")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testPartialJSONWithUnknownKeys() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "name": "Práca",
          "edge": "bottom",
          "layout": "grid",
          "appearance": {"iconSize": 64, "unknownNested": 1},
          "behavior": {"edgeInset": 2},
          "futureTopLevel": {"a": 1}
        }
        """
        let d = try Fixtures.decode(DockConfig.self, json: json)
        XCTAssertEqual(d.id, id)
        XCTAssertEqual(d.name, "Práca")
        XCTAssertEqual(d.edge, .bottom)
        XCTAssertEqual(d.layout, .grid)
        XCTAssertEqual(d.gridLines, 2)
        XCTAssertTrue(d.isEnabled)
        XCTAssertEqual(d.appearance.iconSize, 64)
        XCTAssertEqual(d.appearance.padding, DockAppearance().padding)
        XCTAssertEqual(d.behavior.edgeInset, 2)
        XCTAssertEqual(d.behavior.autoHide, .never)
        XCTAssertTrue(d.categories.isEmpty)
    }

    func testFullRoundTrip() throws {
        let dock = DockConfig(name: "Test", isEnabled: false, edge: .top, layout: .shelves, gridLines: 3,
                              appearance: BuiltInThemes.aurora.appearance,
                              categories: [
                                DockCategory(name: "A", display: .stack, isHidden: true, items: [
                                    DockItem(kind: .app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari")),
                                    DockItem(kind: .app(path: "/Applications/Foo.app", bundleID: nil)),
                                    DockItem(kind: .folder(path: "/Users/me/Downloads"),
                                             folderPresentation: .fan, folderSort: .dateAdded),
                                    DockItem(kind: .file(path: "/Users/me/a.pdf"), customTitle: "PDF"),
                                    DockItem(kind: .link(url: "https://example.com"), customSymbol: "globe",
                                             tint: .white),
                                    DockItem(kind: .separator),
                                    DockItem(kind: .spacer),
                                ]),
                              ],
                              shortcut: KeyShortcut(keyCode: 2, modifiers: [.command, .option], keyLabel: "D"))
        XCTAssertEqual(try Fixtures.roundTrip(dock), dock)
    }
}

final class AppConfigCodableTests: XCTestCase {
    func testEmptyObjectDecodesToDefaults() throws {
        let c = try Fixtures.decode(AppConfig.self, json: "{}")
        XCTAssertEqual(c, AppConfig())
        XCTAssertEqual(c.version, AppConfig.currentVersion)
        XCTAssertTrue(c.docks.isEmpty)
        XCTAssertTrue(c.customThemes.isEmpty)
        XCTAssertFalse(c.launchAtLogin)
        XCTAssertTrue(c.showMenuBarIcon)
        XCTAssertNil(c.toggleAllShortcut)
        XCTAssertNil(c.settingsShortcut)
    }

    func testPartialJSONWithUnknownKeys() throws {
        let json = """
        {
          "version": 1,
          "launchAtLogin": true,
          "docks": [ {"name": "Jeden"}, {"name": "Dva", "edge": "right"} ],
          "toggleAllShortcut": {"keyCode": 2, "modifiers": 3, "keyLabel": "D"},
          "cloudSync": {"enabled": true}
        }
        """
        let c = try Fixtures.decode(AppConfig.self, json: json)
        XCTAssertTrue(c.launchAtLogin)
        XCTAssertTrue(c.showMenuBarIcon)
        XCTAssertEqual(c.docks.map(\.name), ["Jeden", "Dva"])
        XCTAssertEqual(c.docks[1].edge, .right)
        XCTAssertEqual(c.toggleAllShortcut?.modifiers, [.command, .option])
        XCTAssertNil(c.settingsShortcut)
        XCTAssertTrue(c.customThemes.isEmpty)
    }

    func testRoundTripOfStarterConfig() throws {
        var c = AppConfig.starter(homeDirectory: "/Users/tester")
        c.customThemes = [ThemePreset(name: "Môj", appearance: BuiltInThemes.ember.appearance)]
        c.settingsShortcut = KeyShortcut(keyCode: 43, modifiers: [.command, .shift], keyLabel: ",")
        XCTAssertEqual(try Fixtures.roundTrip(c), c)
    }

    func testAllThemesListsBuiltInsFirst() {
        let custom = ThemePreset(name: "Vlastná", appearance: DockAppearance())
        let c = AppConfig(customThemes: [custom])
        XCTAssertEqual(c.allThemes.count, BuiltInThemes.all.count + 1)
        XCTAssertEqual(c.allThemes.last, custom)
        XCTAssertEqual(Array(c.allThemes.prefix(BuiltInThemes.all.count)), BuiltInThemes.all)
    }
}

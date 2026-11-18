import XCTest
@testable import DoxCore

final class ConfigStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: ConfigStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = try Fixtures.makeTempDirectory()
        // A nested folder that does not exist yet: `save` must create it.
        store = ConfigStore(fileURL: tempDir.appendingPathComponent("Dox/config.json"))
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
        store = nil
        try super.tearDownWithError()
    }

    private func mustNotFallBack() -> AppConfig {
        XCTFail("load() unexpectedly used the fallback")
        return AppConfig()
    }

    private var fileExists: Bool { FileManager.default.fileExists(atPath: store.fileURL.path) }
    private var backupExists: Bool { FileManager.default.fileExists(atPath: store.backupURL.path) }

    // MARK: Paths

    func testBackupURLSitsNextToConfig() {
        XCTAssertEqual(store.backupURL.lastPathComponent, "config.backup.json")
        XCTAssertEqual(store.backupURL.deletingLastPathComponent().standardizedFileURL,
                       store.fileURL.deletingLastPathComponent().standardizedFileURL)
    }

    func testDefaultLocation() {
        let url = ConfigStore.defaultLocation()
        XCTAssertEqual(url.lastPathComponent, "config.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Dox")
    }

    // MARK: Save / load

    func testSaveThenLoadRoundTrip() throws {
        var config = AppConfig.starter(homeDirectory: "/Users/tester")
        config.launchAtLogin = true
        config.toggleAllShortcut = KeyShortcut(keyCode: 2, modifiers: [.command, .option], keyLabel: "D")
        config.customThemes = [ThemePreset(name: "Moja téma", appearance: BuiltInThemes.frost.appearance)]

        try store.save(config)
        XCTAssertTrue(fileExists)
        XCTAssertFalse(backupExists, "first save has nothing to back up")
        XCTAssertEqual(store.load(fallback: mustNotFallBack), config)
    }

    func testSavedFileIsPrettySortedJSON() throws {
        try store.save(AppConfig())
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\n"), "pretty printed")
        let customThemes = try XCTUnwrap(text.range(of: "\"customThemes\""))
        let version = try XCTUnwrap(text.range(of: "\"version\""))
        XCTAssertLessThan(customThemes.lowerBound, version.lowerBound, "keys are sorted")
    }

    func testSecondSaveCreatesBackupOfPreviousVersion() throws {
        let first = AppConfig(launchAtLogin: false, showMenuBarIcon: true)
        let second = AppConfig(docks: [DockConfig(name: "Nový")], launchAtLogin: true)

        try store.save(first)
        XCTAssertFalse(backupExists)
        try store.save(second)
        XCTAssertTrue(backupExists)

        let backupData = try Data(contentsOf: store.backupURL)
        XCTAssertEqual(try JSONDecoder().decode(AppConfig.self, from: backupData), first)
        XCTAssertEqual(store.load(fallback: mustNotFallBack), second)

        // A third save rotates the backup to the second version.
        try store.save(AppConfig(showMenuBarIcon: false))
        let rotated = try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: store.backupURL))
        XCTAssertEqual(rotated, second)
    }

    func testLoadFallsBackToBackupWhenMainFileIsCorrupt() throws {
        let good = AppConfig(docks: [DockConfig(name: "Záloha")], launchAtLogin: true)
        try store.save(good)
        try store.save(AppConfig(docks: [DockConfig(name: "Novší")]))
        try Data("{ this is not json".utf8).write(to: store.fileURL)

        XCTAssertEqual(store.load(fallback: mustNotFallBack), good)
    }

    func testLoadFallsBackToBackupWhenMainFileIsMissing() throws {
        let good = AppConfig(launchAtLogin: true)
        try store.save(good)
        try store.save(AppConfig())
        try FileManager.default.removeItem(at: store.fileURL)

        XCTAssertEqual(store.load(fallback: mustNotFallBack), good)
    }

    func testLoadUsesFallbackWhenNothingExists() {
        let marker = AppConfig(docks: [DockConfig(name: "Fallback")], launchAtLogin: true, showMenuBarIcon: false)
        var calls = 0
        let loaded = store.load { calls += 1; return marker }
        XCTAssertEqual(loaded, marker)
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(fileExists, "load must not write anything")
    }

    func testLoadUsesFallbackWhenMainAndBackupAreCorrupt() throws {
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: store.fileURL)
        try Data("[1, 2, 3]".utf8).write(to: store.backupURL)
        let marker = AppConfig(showMenuBarIcon: false)
        XCTAssertEqual(store.load { marker }, marker)
    }

    func testLoadDoesNotCallFallbackWhenFileIsValid() throws {
        try store.save(AppConfig(launchAtLogin: true))
        var calls = 0
        _ = store.load { calls += 1; return AppConfig() }
        XCTAssertEqual(calls, 0)
    }

    // MARK: Import / export

    func testExportImportConfigRoundTrip() throws {
        let config = AppConfig.starter(homeDirectory: "/Users/tester")
        let data = try ConfigStore.exportData(config)
        XCTAssertEqual(try ConfigStore.importConfig(from: data), config)
    }

    func testImportConfigRejectsGarbage() {
        XCTAssertThrowsError(try ConfigStore.importConfig(from: Data("nope".utf8)))
    }

    func testImportThemeAssignsNewIdAndIsNotBuiltIn() throws {
        let original = BuiltInThemes.aurora
        let data = try ConfigStore.exportTheme(original)
        let imported = try ConfigStore.importTheme(from: data)

        XCTAssertNotEqual(imported.id, original.id)
        XCTAssertFalse(imported.isBuiltIn)
        XCTAssertEqual(imported.name, original.name)
        XCTAssertEqual(imported.appearance, original.appearance)

        // Importing the same file twice gives two distinct themes.
        let again = try ConfigStore.importTheme(from: data)
        XCTAssertNotEqual(again.id, imported.id)
    }

    func testImportThemeSanitizesAppearance() throws {
        var wild = DockAppearance()
        wild.iconSize = 999
        wild.magnification = 0
        wild.tintOpacity = -2
        let data = try ConfigStore.exportTheme(ThemePreset(name: "Divoká", appearance: wild, isBuiltIn: true))
        let imported = try ConfigStore.importTheme(from: data)
        XCTAssertFalse(imported.isBuiltIn)
        XCTAssertEqual(imported.appearance, wild.sanitized())
        XCTAssertEqual(imported.appearance.iconSize, 128)
        XCTAssertEqual(imported.appearance.magnification, 1)
        XCTAssertEqual(imported.appearance.tintOpacity, 0)
    }

    func testImportThemeRejectsGarbage() {
        XCTAssertThrowsError(try ConfigStore.importTheme(from: Data("{}".utf8)))
    }
}

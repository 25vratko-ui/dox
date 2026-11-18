import XCTest
@testable import DoxCore

final class DockItemDisplayTitleTests: XCTestCase {
    func testAppTitleDropsExtension() {
        XCTAssertEqual(DockItem(kind: .app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari")).displayTitle,
                       "Safari")
        XCTAssertEqual(DockItem(kind: .app(path: "/Applications/Visual Studio Code.app", bundleID: nil)).displayTitle,
                       "Visual Studio Code")
        XCTAssertEqual(DockItem(kind: .app(path: "/System/Applications/Utilities/Terminal.app", bundleID: nil)).displayTitle,
                       "Terminal")
    }

    func testFolderTitleIsLastPathComponent() {
        XCTAssertEqual(Fixtures.folder("/Users/me/Downloads").displayTitle, "Downloads")
        XCTAssertEqual(Fixtures.folder("/Users/me/Moje projekty").displayTitle, "Moje projekty")
        XCTAssertEqual(Fixtures.folder("/Users/me/Downloads/").displayTitle, "Downloads")
    }

    /// Folders have no "extension": a dot in a folder name is part of its name
    /// (Finder shows "dox.v2", "node.js" or "Release 1.2" in full).
    func testFolderTitleKeepsDotsInName() {
        XCTAssertEqual(Fixtures.folder("/Users/me/Projects/dox.v2").displayTitle, "dox.v2")
        XCTAssertEqual(Fixtures.folder("/Users/me/Release 1.2").displayTitle, "Release 1.2")
    }

    func testFileTitleKeepsExtension() {
        XCTAssertEqual(Fixtures.file("/Users/me/Documents/report.pdf").displayTitle, "report.pdf")
        XCTAssertEqual(Fixtures.file("/Users/me/archive.tar.gz").displayTitle, "archive.tar.gz")
        XCTAssertEqual(Fixtures.file("/Users/me/Makefile").displayTitle, "Makefile")
    }

    func testLinkTitleIsHostWithoutWWW() {
        XCTAssertEqual(Fixtures.link("https://www.apple.com/mac/").displayTitle, "apple.com")
        XCTAssertEqual(Fixtures.link("https://github.com").displayTitle, "github.com")
        XCTAssertEqual(Fixtures.link("https://docs.swift.org/swift-book").displayTitle, "docs.swift.org")
    }

    func testLinkWithoutHostFallsBackToURLString() {
        XCTAssertEqual(Fixtures.link("mailto:hello@example.com").displayTitle, "mailto:hello@example.com")
        XCTAssertEqual(Fixtures.link("not a url at all").displayTitle, "not a url at all")
    }

    func testDecorativeTitles() {
        XCTAssertEqual(DockItem(kind: .separator).displayTitle, "Oddeľovač")
        XCTAssertEqual(DockItem(kind: .spacer).displayTitle, "Medzera")
    }

    func testCustomTitleWins() {
        XCTAssertEqual(DockItem(kind: .app(path: "/Applications/Mail.app", bundleID: nil), customTitle: "Pošta").displayTitle,
                       "Pošta")
        XCTAssertEqual(DockItem(kind: .link(url: "https://github.com"), customTitle: "Kód").displayTitle, "Kód")
        XCTAssertEqual(DockItem(kind: .separator, customTitle: "Čiara").displayTitle, "Čiara")
        // Surrounding whitespace in a non-blank title is kept as typed.
        XCTAssertEqual(DockItem(kind: .file(path: "/a.txt"), customTitle: " Poznámky ").displayTitle, " Poznámky ")
    }

    func testBlankCustomTitleFallsBack() {
        XCTAssertEqual(DockItem(kind: .app(path: "/Applications/Mail.app", bundleID: nil), customTitle: "").displayTitle,
                       "Mail")
        XCTAssertEqual(DockItem(kind: .file(path: "/a/b.txt"), customTitle: "   ").displayTitle, "b.txt")
        XCTAssertEqual(DockItem(kind: .link(url: "https://www.example.org"), customTitle: "\t ").displayTitle,
                       "example.org")
    }

    func testKindHelpers() {
        XCTAssertEqual(DockItemKind.app(path: "/A.app", bundleID: "x").path, "/A.app")
        XCTAssertEqual(DockItemKind.folder(path: "/F").path, "/F")
        XCTAssertEqual(DockItemKind.file(path: "/f.txt").path, "/f.txt")
        XCTAssertNil(DockItemKind.link(url: "https://a.b").path)
        XCTAssertNil(DockItemKind.separator.path)
        XCTAssertEqual(DockItemKind.link(url: "https://a.b").linkURL, "https://a.b")
        XCTAssertNil(DockItemKind.file(path: "/f").linkURL)
        XCTAssertTrue(DockItemKind.separator.isDecorative)
        XCTAssertTrue(DockItemKind.spacer.isDecorative)
        XCTAssertFalse(DockItemKind.link(url: "x").isDecorative)
    }

    func testIdentityKeyPrefersBundleID() {
        XCTAssertEqual(DockItemKind.app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari").identityKey,
                       "app:com.apple.Safari")
        XCTAssertEqual(DockItemKind.app(path: "/Applications/Foo.app", bundleID: nil).identityKey,
                       "app:/Applications/Foo.app")
        XCTAssertEqual(DockItemKind.folder(path: "/x").identityKey, "folder:/x")
        XCTAssertEqual(DockItemKind.file(path: "/x").identityKey, "file:/x")
        XCTAssertEqual(DockItemKind.link(url: "https://x").identityKey, "link:https://x")
        XCTAssertNotEqual(DockItemKind.folder(path: "/x").identityKey, DockItemKind.file(path: "/x").identityKey)
    }
}

final class DockItemInferenceTests: XCTestCase {
    func testAppBundle() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app", isDirectory: true)
        let item = DockItem.inferred(from: url, isDirectory: true, bundleID: "com.apple.Safari")
        XCTAssertEqual(item.kind, .app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari"))
        XCTAssertEqual(item.displayTitle, "Safari")
    }

    func testAppBundleWithoutBundleIDAndUppercaseExtension() {
        let url = URL(fileURLWithPath: "/Applications/Old.APP", isDirectory: true)
        let item = DockItem.inferred(from: url, isDirectory: true)
        XCTAssertEqual(item.kind, .app(path: "/Applications/Old.APP", bundleID: nil))
    }

    func testDirectory() {
        let url = URL(fileURLWithPath: "/Users/me/Projects", isDirectory: true)
        let item = DockItem.inferred(from: url, isDirectory: true)
        XCTAssertEqual(item.kind, .folder(path: "/Users/me/Projects"))
    }

    func testFile() {
        let url = URL(fileURLWithPath: "/Users/me/notes.txt", isDirectory: false)
        let item = DockItem.inferred(from: url, isDirectory: false)
        XCTAssertEqual(item.kind, .file(path: "/Users/me/notes.txt"))
        XCTAssertEqual(item.displayTitle, "notes.txt")
    }

    func testFilePathIsStandardized() {
        let url = URL(fileURLWithPath: "/Users/me/../me/./notes.txt", isDirectory: false)
        let item = DockItem.inferred(from: url, isDirectory: false)
        XCTAssertEqual(item.kind, .file(path: "/Users/me/notes.txt"))
    }

    func testHTTPSURLBecomesLink() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/path?q=1"))
        let item = DockItem.inferred(from: url, isDirectory: false)
        XCTAssertEqual(item.kind, .link(url: "https://example.com/path?q=1"))
        XCTAssertEqual(item.displayTitle, "example.com")
    }

    func testCustomSchemeBecomesLink() throws {
        let url = try XCTUnwrap(URL(string: "mailto:a@b.sk"))
        XCTAssertEqual(DockItem.inferred(from: url, isDirectory: false).kind, .link(url: "mailto:a@b.sk"))
    }

    func testInferredItemsGetDefaults() {
        let item = DockItem.inferred(from: URL(fileURLWithPath: "/tmp/x", isDirectory: true), isDirectory: true)
        XCTAssertNil(item.customTitle)
        XCTAssertNil(item.customSymbol)
        XCTAssertNil(item.tint)
        XCTAssertEqual(item.folderPresentation, .grid)
        XCTAssertEqual(item.folderSort, .name)
    }
}

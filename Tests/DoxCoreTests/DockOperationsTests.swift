import XCTest
@testable import DoxCore

final class DockOperationsTests: XCTestCase {
    private var dock: DockConfig!
    private var catA: UUID!
    private var catB: UUID!

    /// Category "A" holds apps a0…a3, category "B" holds apps b0…b1.
    override func setUp() {
        super.setUp()
        let a = Fixtures.category("A", items: 4, prefix: "a")
        let b = Fixtures.category("B", items: 2, prefix: "b")
        dock = DockConfig(name: "Test", categories: [a, b])
        catA = a.id
        catB = b.id
    }

    override func tearDown() {
        dock = nil
        super.tearDown()
    }

    private func titles(_ categoryID: UUID) -> [String] {
        dock.categories[dock.categoryIndex(categoryID)!].titles
    }

    private func idOf(_ categoryName: String) -> UUID {
        dock.categories.first { $0.name == categoryName }!.id
    }

    private func itemID(_ title: String) -> UUID {
        dock.categories.flatMap(\.items).first { $0.displayTitle == title }!.id
    }

    // MARK: Lookup

    func testLookupHelpers() {
        let id = itemID("b1")
        XCTAssertEqual(dock.categoryIndex(catB), 1)
        XCTAssertNil(dock.categoryIndex(UUID()))
        XCTAssertEqual(dock.location(ofItem: id), ItemLocation(categoryID: catB, itemID: id))
        XCTAssertNil(dock.location(ofItem: UUID()))
        XCTAssertEqual(dock.item(id)?.displayTitle, "b1")
        XCTAssertNil(dock.item(UUID()))
    }

    // MARK: addItem

    func testAddItemAppendsByDefault() {
        XCTAssertTrue(dock.addItem(Fixtures.app("new"), to: catA))
        XCTAssertEqual(titles(catA), ["a0", "a1", "a2", "a3", "new"])
    }

    func testAddItemAtIndex() {
        XCTAssertTrue(dock.addItem(Fixtures.app("new"), to: catA, at: 1))
        XCTAssertEqual(titles(catA), ["a0", "new", "a1", "a2", "a3"])
    }

    func testAddItemClampsIndex() {
        XCTAssertTrue(dock.addItem(Fixtures.app("high"), to: catB, at: 99))
        XCTAssertTrue(dock.addItem(Fixtures.app("low"), to: catB, at: -5))
        XCTAssertEqual(titles(catB), ["low", "b0", "b1", "high"])
    }

    func testAddItemRejectsDuplicateByIdentityKey() {
        // Same path, different item id.
        XCTAssertFalse(dock.addItem(Fixtures.app("a2"), to: catA))
        XCTAssertEqual(titles(catA), ["a0", "a1", "a2", "a3"])

        // Apps are identified by bundle id even when the path differs.
        XCTAssertTrue(dock.addItem(DockItem(kind: .app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari")), to: catB))
        XCTAssertFalse(dock.addItem(DockItem(kind: .app(path: "/Volumes/Old/Safari.app", bundleID: "com.apple.Safari")), to: catB))

        XCTAssertTrue(dock.addItem(Fixtures.link("https://github.com"), to: catB))
        XCTAssertFalse(dock.addItem(Fixtures.link("https://github.com"), to: catB))

        XCTAssertTrue(dock.addItem(Fixtures.folder("/Users/me/x"), to: catB))
        XCTAssertFalse(dock.addItem(Fixtures.folder("/Users/me/x"), to: catB))
        // A file at the same path is a different identity than a folder.
        XCTAssertTrue(dock.addItem(Fixtures.file("/Users/me/x"), to: catB))
        XCTAssertEqual(dock.categories[1].items.count, 2 + 4)
    }

    func testAddItemAllowsSameThingInAnotherCategory() {
        XCTAssertTrue(dock.addItem(Fixtures.app("a0"), to: catB))
        XCTAssertEqual(titles(catB), ["b0", "b1", "a0"])
    }

    func testDecorativeItemsCanBeAddedRepeatedly() {
        XCTAssertTrue(dock.addItem(DockItem(kind: .separator), to: catA))
        XCTAssertTrue(dock.addItem(DockItem(kind: .separator), to: catA))
        XCTAssertTrue(dock.addItem(DockItem(kind: .spacer), to: catA))
        XCTAssertTrue(dock.addItem(DockItem(kind: .spacer), to: catA))
        XCTAssertEqual(dock.categories[0].items.count, 8)
    }

    func testAddItemToUnknownCategoryFails() {
        let before = dock
        XCTAssertFalse(dock.addItem(Fixtures.app("x"), to: UUID()))
        XCTAssertEqual(dock, before)
    }

    // MARK: removeItem / updateItem

    func testRemoveItem() {
        dock.removeItem(itemID("a1"))
        XCTAssertEqual(titles(catA), ["a0", "a2", "a3"])
        XCTAssertEqual(titles(catB), ["b0", "b1"])
    }

    func testRemoveUnknownItemIsNoOp() {
        let before = dock
        dock.removeItem(UUID())
        XCTAssertEqual(dock, before)
    }

    func testUpdateItem() {
        var item = dock.item(itemID("b0"))!
        item.customTitle = "Upravené"
        item.customSymbol = "star"
        dock.updateItem(item)
        XCTAssertEqual(titles(catB), ["Upravené", "b1"])
        XCTAssertEqual(dock.item(item.id), item)
    }

    func testUpdateUnknownItemIsNoOp() {
        let before = dock
        dock.updateItem(Fixtures.app("ghost"))
        XCTAssertEqual(dock, before)
    }

    // MARK: moveItem (index is the insertion slot in the list *before* the move)

    func testMoveItemForwardWithinCategory() {
        dock.moveItem(itemID("a0"), toCategory: catA, at: 3)
        XCTAssertEqual(titles(catA), ["a1", "a2", "a0", "a3"])
    }

    func testMoveItemToEndWithinCategory() {
        dock.moveItem(itemID("a0"), toCategory: catA, at: 4)
        XCTAssertEqual(titles(catA), ["a1", "a2", "a3", "a0"])
    }

    func testMoveItemOneSlotForward() {
        dock.moveItem(itemID("a1"), toCategory: catA, at: 3)
        XCTAssertEqual(titles(catA), ["a0", "a2", "a1", "a3"])
    }

    func testMoveItemBackwardWithinCategory() {
        dock.moveItem(itemID("a3"), toCategory: catA, at: 1)
        XCTAssertEqual(titles(catA), ["a0", "a3", "a1", "a2"])
    }

    func testMoveItemToStartWithinCategory() {
        dock.moveItem(itemID("a2"), toCategory: catA, at: 0)
        XCTAssertEqual(titles(catA), ["a2", "a0", "a1", "a3"])
    }

    func testMoveItemOntoItsOwnSlotIsNoOp() {
        let before = titles(catA)
        dock.moveItem(itemID("a1"), toCategory: catA, at: 1)
        XCTAssertEqual(titles(catA), before)
        dock.moveItem(itemID("a1"), toCategory: catA, at: 2)
        XCTAssertEqual(titles(catA), before)
    }

    func testMoveItemWithinCategoryClampsIndex() {
        dock.moveItem(itemID("a1"), toCategory: catA, at: 99)
        XCTAssertEqual(titles(catA), ["a0", "a2", "a3", "a1"])
        dock.moveItem(itemID("a3"), toCategory: catA, at: -4)
        XCTAssertEqual(titles(catA), ["a3", "a0", "a2", "a1"])
    }

    func testMoveItemAcrossCategories() {
        dock.moveItem(itemID("a0"), toCategory: catB, at: 1)
        XCTAssertEqual(titles(catA), ["a1", "a2", "a3"])
        XCTAssertEqual(titles(catB), ["b0", "a0", "b1"])
    }

    func testMoveItemAcrossCategoriesIndexIsNotShifted() {
        // Moving from a later slot in A to index 2 of B must land at exactly index 2.
        dock.moveItem(itemID("a3"), toCategory: catB, at: 2)
        XCTAssertEqual(titles(catB), ["b0", "b1", "a3"])
        dock.moveItem(itemID("a2"), toCategory: catB, at: 0)
        XCTAssertEqual(titles(catB), ["a2", "b0", "b1", "a3"])
        dock.moveItem(itemID("b1"), toCategory: catA, at: 99)
        XCTAssertEqual(titles(catA), ["a0", "a1", "b1"])
    }

    func testMoveItemToUnknownCategoryIsNoOp() {
        let before = dock
        dock.moveItem(itemID("a0"), toCategory: UUID(), at: 0)
        XCTAssertEqual(dock, before)
    }

    func testMoveUnknownItemIsNoOp() {
        let before = dock
        dock.moveItem(UUID(), toCategory: catA, at: 0)
        XCTAssertEqual(dock, before)
    }

    // MARK: Categories

    func testAddCategoryAtIndex() {
        let c = DockCategory(name: "Nová")
        XCTAssertEqual(dock.addCategory(c, at: 1), c.id)
        XCTAssertEqual(dock.categories.map(\.name), ["A", "Nová", "B"])
    }

    func testAddCategoryAppendsByDefaultAndClamps() {
        dock.addCategory(DockCategory(name: "End"))
        dock.addCategory(DockCategory(name: "Far"), at: 99)
        dock.addCategory(DockCategory(name: "Neg"), at: -3)
        dock.addCategory(DockCategory(name: "Zero"), at: 0)
        XCTAssertEqual(dock.categories.map(\.name), ["Zero", "Neg", "A", "B", "End", "Far"])
    }

    func testRemoveCategory() {
        dock.removeCategory(catA)
        XCTAssertEqual(dock.categories.map(\.name), ["B"])
        dock.removeCategory(UUID())
        XCTAssertEqual(dock.categories.map(\.name), ["B"])
    }

    /// `moveCategory(_:to:)` takes the *final* index of the category (unlike `moveItem`,
    /// whose index is an insertion slot in the pre-move list).
    func testMoveCategory() {
        dock.addCategory(DockCategory(name: "C"))
        dock.addCategory(DockCategory(name: "D"))

        dock.moveCategory(idOf("A"), to: 2)
        XCTAssertEqual(dock.categories.map(\.name), ["B", "C", "A", "D"])

        dock.moveCategory(idOf("D"), to: 0)
        XCTAssertEqual(dock.categories.map(\.name), ["D", "B", "C", "A"])

        dock.moveCategory(idOf("B"), to: 99)
        XCTAssertEqual(dock.categories.map(\.name), ["D", "C", "A", "B"])

        dock.moveCategory(idOf("A"), to: -1)
        XCTAssertEqual(dock.categories.map(\.name), ["A", "D", "C", "B"])

        let before = dock
        dock.moveCategory(UUID(), to: 0)
        XCTAssertEqual(dock, before)
    }

    // MARK: duplicated

    func testDuplicatedHasFreshIdsAndNoShortcut() {
        dock.shortcut = KeyShortcut(keyCode: 2, modifiers: [.command], keyLabel: "D")
        dock.edge = .bottom
        dock.appearance.iconSize = 70
        let copy = dock.duplicated()

        XCTAssertNotEqual(copy.id, dock.id)
        XCTAssertEqual(copy.name, "Test – kópia")
        XCTAssertNil(copy.shortcut)
        XCTAssertEqual(copy.edge, .bottom)
        XCTAssertEqual(copy.appearance, dock.appearance)
        XCTAssertEqual(copy.behavior, dock.behavior)

        XCTAssertEqual(copy.categories.count, dock.categories.count)
        let originalCategoryIDs = Set(dock.categories.map(\.id))
        let originalItemIDs = Set(dock.categories.flatMap(\.items).map(\.id))
        for (c, o) in zip(copy.categories, dock.categories) {
            XCTAssertFalse(originalCategoryIDs.contains(c.id))
            XCTAssertEqual(c.name, o.name)
            XCTAssertEqual(c.items.map(\.kind), o.items.map(\.kind))
            for item in c.items {
                XCTAssertFalse(originalItemIDs.contains(item.id))
            }
        }
        let copyItemIDs = copy.categories.flatMap(\.items).map(\.id)
        XCTAssertEqual(Set(copyItemIDs).count, copyItemIDs.count, "item ids must be unique")
        // The original is untouched.
        XCTAssertNotNil(dock.shortcut)
    }

    func testDuplicatedWithCustomName() {
        XCTAssertEqual(dock.duplicated(name: "Druhý").name, "Druhý")
    }

    // MARK: search

    func testSearchIsCaseAndDiacriticInsensitive() {
        let cal = DockItem(kind: .app(path: "/System/Applications/Calendar.app", bundleID: "com.apple.iCal"),
                           customTitle: "Kalendár")
        dock.addItem(cal, to: catB)
        XCTAssertEqual(dock.search("kalendar").map(\.id), [cal.id])
        XCTAssertEqual(dock.search("KALENDÁR").map(\.id), [cal.id])
        XCTAssertEqual(dock.search("  Kalend  ").map(\.id), [cal.id])
    }

    func testSearchMatchesPathAndURL() {
        let link = Fixtures.link("https://github.com/apple/swift")
        dock.addItem(link, to: catA)
        let cal = DockItem(kind: .app(path: "/System/Applications/Calendar.app", bundleID: nil), customTitle: "Kalendár")
        dock.addItem(cal, to: catB)

        XCTAssertEqual(dock.search("apple/swift").map(\.id), [link.id])
        XCTAssertEqual(dock.search("calendar.app").map(\.id), [cal.id]) // path, not title
        XCTAssertEqual(dock.search("/Applications/").count, 4 + 2 + 1)   // every app
    }

    func testSearchReturnsResultsInDockOrder() {
        XCTAssertEqual(dock.search("a").map(\.displayTitle), ["a0", "a1", "a2", "a3", "b0", "b1"])
        XCTAssertEqual(dock.search("b1").map(\.displayTitle), ["b1"])
    }

    func testSearchIgnoresEmptyQueriesAndDecoratives() {
        dock.addItem(DockItem(kind: .separator), to: catA)
        dock.addItem(DockItem(kind: .spacer), to: catA)
        XCTAssertTrue(dock.search("").isEmpty)
        XCTAssertTrue(dock.search("   ").isEmpty)
        XCTAssertTrue(dock.search("oddelovac").isEmpty)
        XCTAssertTrue(dock.search("Medzera").isEmpty)
        XCTAssertTrue(dock.search("zzz-no-match").isEmpty)
    }

    // MARK: visibility

    func testVisibleCategoriesAndTileCount() {
        let d = DockConfig(name: "V", categories: [
            Fixtures.category("Inline", items: 3),
            Fixtures.category("Hidden", items: 5, hidden: true),
            Fixtures.category("Stack", items: 4, display: .stack),
            Fixtures.category("Empty", items: 0),
            Fixtures.category("HiddenStack", items: 2, display: .stack, hidden: true),
        ])
        XCTAssertEqual(d.visibleCategories.map(\.name), ["Inline", "Stack", "Empty"])
        XCTAssertEqual(d.visibleTileCount, 3 + 1 + 0)
    }

    func testEmptyStackStillCountsAsOneTile() {
        let d = DockConfig(name: "V", categories: [Fixtures.category("S", items: 0, display: .stack)])
        XCTAssertEqual(d.visibleTileCount, 1)
    }

    func testNoCategories() {
        let d = DockConfig(name: "V")
        XCTAssertTrue(d.visibleCategories.isEmpty)
        XCTAssertEqual(d.visibleTileCount, 0)
    }
}

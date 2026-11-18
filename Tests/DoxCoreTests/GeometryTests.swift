import XCTest
@testable import DoxCore

final class MagnificationScaleTests: XCTestCase {
    private let eps = 1e-9

    private func scale(_ distance: Double, iconSize: Double = 48, magnification: Double = 1.6,
                       spread: Double = 2.5) -> Double {
        DockGeometry.magnificationScale(distance: distance, iconSize: iconSize,
                                        magnification: magnification, spread: spread)
    }

    func testPeakAtPointerEqualsMagnification() {
        XCTAssertEqual(scale(0), 1.6, accuracy: eps)
        XCTAssertEqual(scale(0, magnification: 3), 3, accuracy: eps)
        XCTAssertEqual(scale(0, magnification: 1.01), 1.01, accuracy: eps)
    }

    func testHalfwayIsHalfTheBoost() {
        // reach = 2.5 * 48 = 120; at 60 the cosine falloff is exactly 0.5.
        XCTAssertEqual(scale(60), 1.3, accuracy: eps)
        XCTAssertEqual(scale(-60), 1.3, accuracy: eps)
    }

    func testOneAtAndBeyondReach() {
        XCTAssertEqual(scale(120), 1)
        XCTAssertEqual(scale(-120), 1)
        XCTAssertEqual(scale(121), 1)
        XCTAssertEqual(scale(10_000), 1)
        XCTAssertEqual(scale(-10_000), 1)
        // Just inside the reach it is still (slightly) magnified.
        XCTAssertGreaterThan(scale(119), 1)
    }

    func testSymmetric() {
        for d in stride(from: 0.0, through: 130.0, by: 7.5) {
            XCTAssertEqual(scale(d), scale(-d), accuracy: eps, "distance \(d)")
        }
    }

    func testStrictlyDecreasingInsideReach() {
        var previous = scale(0)
        for d in stride(from: 5.0, to: 120.0, by: 5.0) {
            let s = scale(d)
            XCTAssertLessThan(s, previous, "distance \(d)")
            XCTAssertGreaterThan(s, 1, "distance \(d)")
            XCTAssertLessThanOrEqual(s, 1.6 + eps, "distance \(d)")
            previous = s
        }
        XCTAssertLessThan(scale(120), previous)
    }

    func testNoMagnificationWhenDisabledOrDegenerate() {
        XCTAssertEqual(scale(0, magnification: 1), 1)
        XCTAssertEqual(scale(10, magnification: 1), 1)
        XCTAssertEqual(scale(0, magnification: 0.5), 1)
        XCTAssertEqual(scale(0, iconSize: 0), 1)
        XCTAssertEqual(scale(0, spread: 0), 1)
        XCTAssertEqual(scale(0, spread: -1), 1)
    }

    func testReachScalesWithIconSizeAndSpread() {
        // iconSize 32, spread 2 → reach 64.
        XCTAssertEqual(scale(64, iconSize: 32, spread: 2), 1)
        XCTAssertEqual(scale(32, iconSize: 32, spread: 2), 1.3, accuracy: eps)
        XCTAssertGreaterThan(scale(63, iconSize: 32, spread: 2), 1)
    }

    func testHeadroom() {
        var a = DockAppearance()
        a.iconSize = 50
        a.magnification = 2
        a.hoverEffect = .magnify
        XCTAssertEqual(DockGeometry.magnificationHeadroom(for: a), 50, accuracy: eps)
        a.hoverEffect = .lift
        XCTAssertEqual(DockGeometry.magnificationHeadroom(for: a), 15, accuracy: eps)
        a.hoverEffect = .glow
        XCTAssertEqual(DockGeometry.magnificationHeadroom(for: a), 8)
        a.hoverEffect = .none
        XCTAssertEqual(DockGeometry.magnificationHeadroom(for: a), 8)
    }
}

final class LayoutSizeTests: XCTestCase {
    private let eps = 1e-9

    /// iconSize 40, iconSpacing 10, categorySpacing 20, padding 5.
    /// Visible: "A" inline (3 items) + "B" stack (4 items → 1 tile). "C" (2 items) is hidden.
    private func makeDock(layout: DockLayoutStyle, gridLines: Int = 2) -> DockConfig {
        var a = DockAppearance()
        a.iconSize = 40
        a.iconSpacing = 10
        a.categorySpacing = 20
        a.padding = 5
        return DockConfig(name: "G", layout: layout, gridLines: gridLines, appearance: a, categories: [
            Fixtures.category("A", items: 3),
            Fixtures.category("B", items: 4, display: .stack),
            Fixtures.category("C", items: 2, hidden: true),
        ])
    }

    // MARK: lineCount

    func testLineCountForLine() {
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .line)), 1)
    }

    func testLineCountForGrid() {
        // 4 visible tiles.
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .grid, gridLines: 2)), 2)
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .grid, gridLines: 3)), 3)
        // Never more lines than tiles.
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .grid, gridLines: 10)), 4)
        // Never fewer than one.
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .grid, gridLines: 0)), 1)
        XCTAssertEqual(DockGeometry.lineCount(for: DockConfig(name: "E", layout: .grid, gridLines: 3)), 1)
    }

    func testLineCountForShelves() {
        // One shelf per visible category (hidden "C" excluded).
        XCTAssertEqual(DockGeometry.lineCount(for: makeDock(layout: .shelves)), 2)
        XCTAssertEqual(DockGeometry.lineCount(for: DockConfig(name: "E", layout: .shelves)), 1)
    }

    // MARK: restingSize

    func testRestingSizeLine() {
        // A: 3*40 + 2*10 = 140, + categorySpacing 20 = 160
        // B: 1*40 + 0    =  40                       → 200
        // + padding 2*5 = 210. Thickness: 40 + 2*5 = 50.
        let size = DockGeometry.restingSize(for: makeDock(layout: .line))
        XCTAssertEqual(size.length, 210, accuracy: eps)
        XCTAssertEqual(size.thickness, 50, accuracy: eps)
    }

    func testRestingSizeLineWithHeaderExtent() {
        // Header extent is added once per visible category: 210 + 2*6 = 222.
        let size = DockGeometry.restingSize(for: makeDock(layout: .line), headerExtent: 6)
        XCTAssertEqual(size.length, 222, accuracy: eps)
        XCTAssertEqual(size.thickness, 50, accuracy: eps)
    }

    func testRestingSizeLineSingleCategoryHasNoCategorySpacing() {
        var dock = makeDock(layout: .line)
        dock.categories = [Fixtures.category("Solo", items: 5)]
        // 5*40 + 4*10 = 240, + 10 padding = 250.
        let size = DockGeometry.restingSize(for: dock)
        XCTAssertEqual(size.length, 250, accuracy: eps)
        XCTAssertEqual(size.thickness, 50, accuracy: eps)
    }

    func testRestingSizeLineCountsEmptyCategoryAsZeroLength() {
        var dock = makeDock(layout: .line)
        dock.categories.append(Fixtures.category("Empty", items: 0))
        // 160 (A + spacing) + 40 (B) + 20 (spacing before Empty) + 0 = 220, + 10 = 230.
        XCTAssertEqual(DockGeometry.restingSize(for: dock).length, 230, accuracy: eps)
    }

    func testRestingSizeGrid() {
        // 4 tiles over 2 lines → 2 per line: 2*40 + 10 = 90 (+10 padding) = 100.
        // Thickness: 2*40 + 1*10 = 90 (+10) = 100.
        let size = DockGeometry.restingSize(for: makeDock(layout: .grid, gridLines: 2))
        XCTAssertEqual(size.length, 100, accuracy: eps)
        XCTAssertEqual(size.thickness, 100, accuracy: eps)

        // 4 tiles over 3 lines → ceil(4/3) = 2 per line; thickness 3*40 + 2*10 = 140 (+10) = 150.
        let three = DockGeometry.restingSize(for: makeDock(layout: .grid, gridLines: 3), headerExtent: 7)
        XCTAssertEqual(three.length, 100 + 7, accuracy: eps)
        XCTAssertEqual(three.thickness, 150, accuracy: eps)
    }

    func testRestingSizeShelves() {
        // Longest visible shelf = 3 tiles: 3*40 + 2*10 = 140 (+10) = 150.
        // Two shelves: 2*40 + 1*categorySpacing(20) = 100 (+10) = 110.
        let size = DockGeometry.restingSize(for: makeDock(layout: .shelves))
        XCTAssertEqual(size.length, 150, accuracy: eps)
        XCTAssertEqual(size.thickness, 110, accuracy: eps)
    }

    func testRestingSizeEmptyDockIsOneTile() {
        var dock = makeDock(layout: .line)
        dock.categories = []
        let size = DockGeometry.restingSize(for: dock)
        XCTAssertEqual(size.length, 50, accuracy: eps)
        XCTAssertEqual(size.thickness, 50, accuracy: eps)

        // Only hidden categories → same as empty.
        dock.categories = [Fixtures.category("H", items: 3, hidden: true)]
        XCTAssertEqual(DockGeometry.restingSize(for: dock).length, 50, accuracy: eps)
    }
}

final class DockOriginTests: XCTestCase {
    private let eps = 1e-9

    private struct Screen {
        var x: Double, y: Double, width: Double, height: Double
    }

    private let mainScreen = Screen(x: 0, y: 0, width: 1000, height: 800)
    /// A secondary display to the right of a 1440-wide main display, slightly raised.
    private let sideScreen = Screen(x: 1440, y: 0, width: 1000, height: 800)
    private let raisedScreen = Screen(x: 1440, y: 120, width: 1000, height: 800)

    private func origin(_ w: Double, _ h: Double, on s: Screen, edge: DockEdge, alignment: EdgeAlignment,
                        offset: Double = 0, inset: Double = 8) -> (x: Double, y: Double) {
        DockGeometry.origin(bodyWidth: w, bodyHeight: h,
                            screenX: s.x, screenY: s.y, screenWidth: s.width, screenHeight: s.height,
                            edge: edge, alignment: alignment, offset: offset, inset: inset)
    }

    private func assertOrigin(_ o: (x: Double, y: Double), _ x: Double, _ y: Double,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(o.x, x, accuracy: eps, "x", file: file, line: line)
        XCTAssertEqual(o.y, y, accuracy: eps, "y", file: file, line: line)
    }

    // MARK: Vertical edges (body 100 × 300). Bottom-left origin: "leading" = top of screen.

    func testLeftEdge() {
        assertOrigin(origin(100, 300, on: mainScreen, edge: .left, alignment: .center), 8, 250)
        assertOrigin(origin(100, 300, on: mainScreen, edge: .left, alignment: .leading), 8, 500)
        assertOrigin(origin(100, 300, on: mainScreen, edge: .left, alignment: .trailing), 8, 0)
    }

    func testRightEdge() {
        assertOrigin(origin(100, 300, on: mainScreen, edge: .right, alignment: .center), 892, 250)
        assertOrigin(origin(100, 300, on: mainScreen, edge: .right, alignment: .leading), 892, 500)
        assertOrigin(origin(100, 300, on: mainScreen, edge: .right, alignment: .trailing), 892, 0)
    }

    // MARK: Horizontal edges (body 400 × 60).

    func testTopEdge() {
        assertOrigin(origin(400, 60, on: mainScreen, edge: .top, alignment: .center), 300, 732)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .top, alignment: .leading), 0, 732)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .top, alignment: .trailing), 600, 732)
    }

    func testBottomEdge() {
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center), 300, 8)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .leading), 0, 8)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .trailing), 600, 8)
    }

    // MARK: Offset screens

    func testOffsetScreen() {
        assertOrigin(origin(100, 300, on: sideScreen, edge: .left, alignment: .center), 1448, 250)
        assertOrigin(origin(100, 300, on: sideScreen, edge: .left, alignment: .leading), 1448, 500)
        assertOrigin(origin(100, 300, on: sideScreen, edge: .right, alignment: .center), 2332, 250)
        assertOrigin(origin(400, 60, on: sideScreen, edge: .top, alignment: .center), 1740, 732)
        assertOrigin(origin(400, 60, on: sideScreen, edge: .bottom, alignment: .leading), 1440, 8)
        assertOrigin(origin(400, 60, on: sideScreen, edge: .bottom, alignment: .trailing), 2040, 8)
    }

    func testRaisedOffsetScreen() {
        assertOrigin(origin(100, 300, on: raisedScreen, edge: .left, alignment: .center), 1448, 370)
        assertOrigin(origin(100, 300, on: raisedScreen, edge: .left, alignment: .leading), 1448, 620)
        assertOrigin(origin(100, 300, on: raisedScreen, edge: .right, alignment: .trailing), 2332, 120)
        assertOrigin(origin(400, 60, on: raisedScreen, edge: .top, alignment: .center), 1740, 852)
        assertOrigin(origin(400, 60, on: raisedScreen, edge: .bottom, alignment: .center), 1740, 128)
    }

    // MARK: Alignment offset

    func testAlignmentOffsetShiftsAlongEdgeAndIsClamped() {
        // Horizontal: free = 600, center base = 300.
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center, offset: 0.1), 400, 8)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center, offset: -0.1), 200, 8)
        // 300 + 0.5 * 1000 = 800 → clamped to the free space (600).
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center, offset: 0.5), 600, 8)
        // Offset itself is clamped to -0.5, then position to 0.
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center, offset: -3), 0, 8)
        // Vertical: positive offset moves toward "trailing" (down). free = 500, base 250 + 80 = 330 from top.
        assertOrigin(origin(100, 300, on: mainScreen, edge: .left, alignment: .center, offset: 0.1), 8, 170)
        // Same on an offset screen.
        assertOrigin(origin(400, 60, on: sideScreen, edge: .top, alignment: .leading, offset: 0.25), 1690, 732)
    }

    func testInsetIsRespected() {
        assertOrigin(origin(100, 300, on: mainScreen, edge: .left, alignment: .center, inset: 0), 0, 250)
        assertOrigin(origin(100, 300, on: mainScreen, edge: .right, alignment: .center, inset: 20), 880, 250)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .top, alignment: .center, inset: 20), 300, 720)
        assertOrigin(origin(400, 60, on: mainScreen, edge: .bottom, alignment: .center, inset: 20), 300, 20)
    }

    /// Exhaustive sanity check: every edge/alignment/offset keeps the body on screen,
    /// flush with the inset on its own edge.
    func testDockAlwaysStaysWithinScreen() {
        let screens = [mainScreen, sideScreen, raisedScreen]
        let offsets: [Double] = [-1, -0.5, -0.2, 0, 0.2, 0.5, 1]
        let inset = 12.0
        for s in screens {
            for edge in DockEdge.allCases {
                let (w, h): (Double, Double) = edge.isVertical ? (90, 640) : (720, 90)
                for alignment in EdgeAlignment.allCases {
                    for offset in offsets {
                        let o = origin(w, h, on: s, edge: edge, alignment: alignment, offset: offset, inset: inset)
                        let ctx = "\(edge) \(alignment) offset \(offset) screen x=\(s.x) y=\(s.y)"
                        XCTAssertGreaterThanOrEqual(o.x, s.x - eps, ctx)
                        XCTAssertGreaterThanOrEqual(o.y, s.y - eps, ctx)
                        XCTAssertLessThanOrEqual(o.x + w, s.x + s.width + eps, ctx)
                        XCTAssertLessThanOrEqual(o.y + h, s.y + s.height + eps, ctx)
                        switch edge {
                        case .left: XCTAssertEqual(o.x, s.x + inset, accuracy: eps, ctx)
                        case .right: XCTAssertEqual(o.x + w, s.x + s.width - inset, accuracy: eps, ctx)
                        case .top: XCTAssertEqual(o.y + h, s.y + s.height - inset, accuracy: eps, ctx)
                        case .bottom: XCTAssertEqual(o.y, s.y + inset, accuracy: eps, ctx)
                        }
                    }
                }
            }
        }
    }
}

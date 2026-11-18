import XCTest
@testable import DoxCore

final class RGBAColorTests: XCTestCase {
    private let eps = 1e-9

    func testParsesShortHexRGB() throws {
        let c = try XCTUnwrap(RGBAColor(hex: "#F80"))
        // #F80 expands to #FF8800.
        XCTAssertEqual(c.red, 1, accuracy: eps)
        XCTAssertEqual(c.green, 136.0 / 255.0, accuracy: eps)
        XCTAssertEqual(c.blue, 0, accuracy: eps)
        XCTAssertEqual(c.alpha, 1, accuracy: eps)
        XCTAssertEqual(c.hexString, "#FF8800")
    }

    func testParsesSixDigitHex() throws {
        let c = try XCTUnwrap(RGBAColor(hex: "#336699"))
        XCTAssertEqual(c.red, 0x33 / 255.0, accuracy: eps)   // 0.2
        XCTAssertEqual(c.green, 0x66 / 255.0, accuracy: eps) // 0.4
        XCTAssertEqual(c.blue, 0x99 / 255.0, accuracy: eps)  // 0.6
        XCTAssertEqual(c.red, 0.2, accuracy: eps)
        XCTAssertEqual(c.green, 0.4, accuracy: eps)
        XCTAssertEqual(c.blue, 0.6, accuracy: eps)
        XCTAssertEqual(c.alpha, 1, accuracy: eps)
    }

    func testParsesEightDigitHexWithAlpha() throws {
        let c = try XCTUnwrap(RGBAColor(hex: "#11223380"))
        XCTAssertEqual(c.red, 0x11 / 255.0, accuracy: eps)
        XCTAssertEqual(c.green, 0x22 / 255.0, accuracy: eps)
        XCTAssertEqual(c.blue, 0x33 / 255.0, accuracy: eps)
        XCTAssertEqual(c.alpha, 128.0 / 255.0, accuracy: eps)
    }

    func testHashIsOptionalAndCaseAndWhitespaceAreIgnored() throws {
        XCTAssertEqual(RGBAColor(hex: "00FF00"), RGBAColor(red: 0, green: 1, blue: 0))
        XCTAssertEqual(RGBAColor(hex: "abc"), RGBAColor(hex: "#AABBCC"))
        XCTAssertEqual(RGBAColor(hex: "#ff8000"), RGBAColor(hex: "#FF8000"))
        XCTAssertEqual(RGBAColor(hex: "  #FF8000\n"), RGBAColor(hex: "#FF8000"))
        XCTAssertEqual(RGBAColor(hex: "11223380"), RGBAColor(hex: "#11223380"))
    }

    func testInvalidHexReturnsNil() {
        let invalid = ["", "#", "#1", "#12", "#1234", "#12345", "#1234567", "#123456789",
                       "#GGGGGG", "#12345Z", "zzz", "#FF 000", "##FFFFFF", "rgb(1,2,3)"]
        for s in invalid {
            XCTAssertNil(RGBAColor(hex: s), "expected nil for \"\(s)\"")
        }
    }

    /// `UInt64(_:radix:)` accepts a leading sign, so a sign must not sneak through as a "digit".
    func testHexWithSignCharacterIsRejected() {
        XCTAssertNil(RGBAColor(hex: "#+12345"))
        XCTAssertNil(RGBAColor(hex: "+FFFFF"))
        XCTAssertNil(RGBAColor(hex: "#+1234567"))
    }

    func testHexStringOmitsAlphaWhenOpaque() {
        XCTAssertEqual(RGBAColor.white.hexString, "#FFFFFF")
        XCTAssertEqual(RGBAColor.black.hexString, "#000000")
        XCTAssertEqual(RGBAColor.clear.hexString, "#00000000")
        XCTAssertEqual(RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5).hexString, "#FF000080")
    }

    func testHexStringRoundTrip() throws {
        for hex in ["#000000", "#FFFFFF", "#7C8CFF", "#14141A", "#5EF2C2", "#C2410C",
                    "#11223380", "#FF4FD800", "#0A84FF7F"] {
            let c = try XCTUnwrap(RGBAColor(hex: hex), hex)
            XCTAssertEqual(c.hexString, hex)
            XCTAssertEqual(RGBAColor(hex: c.hexString), c, hex)
        }
        // Lowercase input normalises to uppercase output.
        XCTAssertEqual(RGBAColor(hex: "#abcdef")?.hexString, "#ABCDEF")
        // Short form expands.
        XCTAssertEqual(RGBAColor(hex: "#abc")?.hexString, "#AABBCC")
    }

    func testInitClampsComponents() {
        let c = RGBAColor(red: 2, green: -1, blue: 0.5, alpha: 7)
        XCTAssertEqual(c.red, 1)
        XCTAssertEqual(c.green, 0)
        XCTAssertEqual(c.blue, 0.5)
        XCTAssertEqual(c.alpha, 1)

        let d = RGBAColor(red: -0.1, green: 1.1, blue: -5, alpha: -1)
        XCTAssertEqual(d.red, 0)
        XCTAssertEqual(d.green, 1)
        XCTAssertEqual(d.blue, 0)
        XCTAssertEqual(d.alpha, 0)
    }

    func testWithAlphaClampsAndKeepsColor() {
        let base = RGBAColor(red: 0.2, green: 0.4, blue: 0.6)
        XCTAssertEqual(base.withAlpha(0.3), RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.3))
        XCTAssertEqual(base.withAlpha(3).alpha, 1)
        XCTAssertEqual(base.withAlpha(-3).alpha, 0)
    }

    func testCodableRoundTrip() throws {
        let c = RGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        XCTAssertEqual(try Fixtures.roundTrip(c), c)
    }

    func testClampedHelper() {
        XCTAssertEqual(5.clamped(to: 0...3), 3)
        XCTAssertEqual((-2).clamped(to: 0...3), 0)
        XCTAssertEqual(2.clamped(to: 0...3), 2)
        XCTAssertEqual(1.5.clamped(to: 0...1), 1.0)
    }
}

final class KeyShortcutTests: XCTestCase {
    func testDisplayStringUsesStandardModifierOrder() {
        let all = KeyShortcut(keyCode: 2, modifiers: [.command, .shift, .option, .control], keyLabel: "d")
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘D")

        XCTAssertEqual(KeyShortcut(keyCode: 2, modifiers: [.command, .option], keyLabel: "D").displayString, "⌥⌘D")
        XCTAssertEqual(KeyShortcut(keyCode: 2, modifiers: [.command, .control], keyLabel: "D").displayString, "⌃⌘D")
        XCTAssertEqual(KeyShortcut(keyCode: 2, modifiers: [.shift, .control], keyLabel: "D").displayString, "⌃⇧D")
        XCTAssertEqual(KeyShortcut(keyCode: 96, modifiers: [.command], keyLabel: "F5").displayString, "⌘F5")
        XCTAssertEqual(KeyShortcut(keyCode: 49, modifiers: [.option], keyLabel: "Space").displayString, "⌥SPACE")
        XCTAssertEqual(KeyShortcut(keyCode: 2, modifiers: [], keyLabel: "d").displayString, "D")
    }

    func testIsValidGlobalShortcutRequiresAModifier() {
        XCTAssertFalse(KeyShortcut(keyCode: 2, modifiers: [], keyLabel: "D").isValidGlobalShortcut)
        XCTAssertTrue(KeyShortcut(keyCode: 2, modifiers: [.shift], keyLabel: "D").isValidGlobalShortcut)
        XCTAssertTrue(KeyShortcut(keyCode: 2, modifiers: [.command], keyLabel: "D").isValidGlobalShortcut)
        XCTAssertTrue(KeyShortcut(keyCode: 2, modifiers: [.control, .option], keyLabel: "D").isValidGlobalShortcut)
    }

    func testModifierRawValuesAreStable() {
        // Raw values are persisted on disk; changing them would break saved shortcuts.
        XCTAssertEqual(KeyShortcut.Modifiers.command.rawValue, 1)
        XCTAssertEqual(KeyShortcut.Modifiers.option.rawValue, 2)
        XCTAssertEqual(KeyShortcut.Modifiers.control.rawValue, 4)
        XCTAssertEqual(KeyShortcut.Modifiers.shift.rawValue, 8)
    }

    func testCodableRoundTrip() throws {
        let s = KeyShortcut(keyCode: 49, modifiers: [.command, .option, .shift], keyLabel: "Space")
        let decoded = try Fixtures.roundTrip(s)
        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.modifiers, [.command, .option, .shift])
        XCTAssertEqual(decoded.keyCode, 49)
        XCTAssertEqual(decoded.keyLabel, "Space")
    }

    func testDecodesModifiersFromRawInteger() throws {
        let s = try Fixtures.decode(KeyShortcut.self,
                                    json: #"{"keyCode": 2, "modifiers": 5, "keyLabel": "D"}"#)
        XCTAssertEqual(s.modifiers, [.command, .control])
        XCTAssertEqual(s.displayString, "⌃⌘D")
    }
}

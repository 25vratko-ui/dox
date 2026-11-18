import Foundation
import XCTest
@testable import DoxCore

/// Shared helpers for the DoxCore test suite.
enum Fixtures {
    static func decode<T: Decodable>(_ type: T.Type, json: String,
                                     file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let data = try XCTUnwrap(json.data(using: .utf8), file: file, line: line)
        return try JSONDecoder().decode(type, from: data)
    }

    static func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func app(_ name: String, bundleID: String? = nil) -> DockItem {
        DockItem(kind: .app(path: "/Applications/\(name).app", bundleID: bundleID))
    }

    static func folder(_ path: String) -> DockItem {
        DockItem(kind: .folder(path: path))
    }

    static func file(_ path: String) -> DockItem {
        DockItem(kind: .file(path: path))
    }

    static func link(_ url: String) -> DockItem {
        DockItem(kind: .link(url: url))
    }

    /// A category with `count` distinct app items named "<prefix>0", "<prefix>1", ...
    static func category(_ name: String, items count: Int, prefix: String? = nil,
                         display: CategoryDisplay = .inline, hidden: Bool = false) -> DockCategory {
        let p = prefix ?? name
        let items = (0..<count).map { app("\(p)\($0)") }
        return DockCategory(name: name, display: display, isHidden: hidden, items: items)
    }

    /// Temporary directory unique to one test; caller removes it in tearDown.
    static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DoxCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension DockCategory {
    /// Display titles of the items, handy for asserting exact ordering.
    var titles: [String] { items.map(\.displayTitle) }
}

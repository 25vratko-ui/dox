import Foundation
import UniformTypeIdentifiers
import DoxCore

/// Lists a folder for stack popovers.
enum FolderContents {
    private struct Entry {
        let url: URL
        let name: String
        let modified: Date
        let added: Date
        let kind: String
    }

    /// Visible (non-hidden) entries of `path`, sorted. `limit <= 0` means no limit.
    static func items(in path: String, sort: FolderSort, limit: Int) -> [URL] {
        let dir = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        let keys: [URLResourceKey] = [.localizedNameKey, .contentModificationDateKey,
                                      .addedToDirectoryDateKey, .creationDateKey, .contentTypeKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }

        let entries: [Entry] = urls.map { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            return Entry(url: url,
                         name: v?.localizedName ?? url.lastPathComponent,
                         modified: v?.contentModificationDate ?? .distantPast,
                         added: v?.addedToDirectoryDate ?? v?.creationDate ?? .distantPast,
                         kind: v?.contentType?.identifier ?? "")
        }

        func byName(_ a: Entry, _ b: Entry) -> Bool {
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        let sorted: [Entry]
        switch sort {
        case .name:
            sorted = entries.sorted(by: byName)
        case .dateModified:
            sorted = entries.sorted { $0.modified != $1.modified ? $0.modified > $1.modified : byName($0, $1) }
        case .dateAdded:
            sorted = entries.sorted { $0.added != $1.added ? $0.added > $1.added : byName($0, $1) }
        case .kind:
            sorted = entries.sorted { $0.kind != $1.kind ? $0.kind < $1.kind : byName($0, $1) }
        }
        let result = sorted.map(\.url)
        return limit > 0 ? Array(result.prefix(limit)) : result
    }
}

import Foundation

/// Reads and writes `AppConfig` as pretty JSON. Writes are atomic and keep one backup.
public struct ConfigStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/Dox/config.json`
    public static func defaultLocation() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Dox", isDirectory: true).appendingPathComponent("config.json")
    }

    public var backupURL: URL { fileURL.deletingPathExtension().appendingPathExtension("backup.json") }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    /// Loads the config. Falls back to the backup, then to `fallback()` (first launch).
    public func load(fallback: () -> AppConfig = { AppConfig.starter() }) -> AppConfig {
        for url in [fileURL, backupURL] {
            if let data = try? Data(contentsOf: url),
               let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                return config
            }
        }
        return fallback()
    }

    public func save(_ config: AppConfig) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Self.encoder().encode(config)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: Import / export

    public static func exportData(_ config: AppConfig) throws -> Data { try encoder().encode(config) }
    public static func importConfig(from data: Data) throws -> AppConfig { try JSONDecoder().decode(AppConfig.self, from: data) }

    public static func exportTheme(_ theme: ThemePreset) throws -> Data { try encoder().encode(theme) }

    /// Imports a theme file, always as a user (non built-in) theme with a fresh id.
    public static func importTheme(from data: Data) throws -> ThemePreset {
        var t = try JSONDecoder().decode(ThemePreset.self, from: data)
        t.id = UUID()
        t.isBuiltIn = false
        t.appearance = t.appearance.sanitized()
        return t
    }
}

import Foundation

/// Persistent color library stored as JSON in ~/.config/farbauswahl/library.json
final class ColorLibrary {
    struct Entry: Codable, Identifiable {
        let id: UUID
        let color: ColorValue
        let name: String?
        let tailwindMatch: String?
        let savedAt: Date

        init(color: ColorValue) {
            self.id = UUID()
            self.color = color
            self.name = ColorNames.shared.nearest(to: color)?.name
            self.tailwindMatch = TailwindColors.shared.nearest(to: color)?.name
            self.savedAt = Date()
        }
    }

    private(set) var entries: [Entry] = []
    private let fileURL: URL

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/farbauswahl", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        fileURL = configDir.appendingPathComponent("library.json")
        load()
    }

    func add(color: ColorValue) {
        let entry = Entry(color: color)
        entries.insert(entry, at: 0)
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func colors(limit: Int = 24) -> [ColorValue] {
        Array(entries.prefix(limit).map(\.color))
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([Entry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("[Farbauswahl] Failed to save library: \(error)\n".utf8))
        }
    }
}

import Foundation

final class SaveStore {
    static let shared = SaveStore()

    let rootURL: URL
    let tracksURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL? = nil) {
        let base = rootURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ApexSlotRacing", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ApexSlotRacing", isDirectory: true)

        self.rootURL = base
        self.tracksURL = base.appendingPathComponent("Tracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.tracksURL, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Decodable>(_ type: T.Type, named name: String, fallback: T) -> T {
        let url = rootURL.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return fallback }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            NSLog("ApexSlotRacing: failed to decode \(name): \(error)")
            return fallback
        }
    }

    @discardableResult
    func save<T: Encodable>(_ value: T, named name: String) -> Bool {
        do {
            let data = try encoder.encode(value)
            try data.write(to: rootURL.appendingPathComponent(name), options: .atomic)
            return true
        } catch {
            NSLog("ApexSlotRacing: failed to save \(name): \(error)")
            return false
        }
    }

    func delete(named name: String) {
        let url = rootURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    func loadProfile() -> PlayerProfile {
        load(PlayerProfile.self, named: "profile.json", fallback: .fresh())
    }

    func saveProfile(_ profile: PlayerProfile) {
        save(profile, named: "profile.json")
    }

    func loadChampionship() -> ChampionshipState? {
        let url = rootURL.appendingPathComponent("championship.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(ChampionshipState.self, from: data)
    }

    func saveChampionship(_ state: ChampionshipState?) {
        guard let state else {
            delete(named: "championship.json")
            return
        }
        save(state, named: "championship.json")
    }

    func loadCustomTracks() -> [TrackLayout] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: tracksURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> TrackLayout? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                var track = try? decoder.decode(TrackLayout.self, from: data)
                track?.isBuiltIn = false
                return track
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveTrack(_ track: TrackLayout) {
        var track = track
        track.isBuiltIn = false
        track.updatedAt = Date()
        save(track, named: "Tracks/\(track.id.uuidString).json")
    }

    func deleteTrack(id: UUID) {
        let url = tracksURL.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    func encodeTrack(_ track: TrackLayout) throws -> Data {
        try encoder.encode(track)
    }

    func decodeTrack(_ data: Data) throws -> TrackLayout {
        try decoder.decode(TrackLayout.self, from: data)
    }

    func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }
}

enum SettingsStore {
    private static let key = "apexSlotRacing.settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

import AppKit
import Foundation
import UniformTypeIdentifiers

enum TrackCodecError: LocalizedError {
    case invalidJSON
    case unsupportedSchema(Int)
    case noStartPiece
    case duplicateStart
    case emptyTrack
    case openCircuit(Float)
    case tooShort

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "That file is not valid track JSON."
        case .unsupportedSchema(let version):
            return "Track schema version \(version) is not supported."
        case .noStartPiece:
            return "A circuit needs exactly one start/finish piece."
        case .duplicateStart:
            return "A circuit can only contain one start/finish piece."
        case .emptyTrack:
            return "The circuit does not contain any pieces."
        case .openCircuit(let gap):
            return String(format: "The circuit is open by %.2f track units. Close the loop before racing.", gap)
        case .tooShort:
            return "The circuit is too short to race."
        }
    }
}

enum TrackFileService {
    @MainActor
    static func export(_ layout: TrackLayout) -> Result<URL, Error> {
        let panel = NSSavePanel()
        panel.title = "Export Circuit"
        panel.nameFieldStringValue = sanitizedFilename(layout.name) + ".json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure(CocoaError(.userCancelled))
        }
        do {
            let data = try SaveStore.shared.encodeTrack(layout)
            try data.write(to: url, options: .atomic)
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    @MainActor
    static func importTrack() -> Result<TrackLayout, Error> {
        let panel = NSOpenPanel()
        panel.title = "Import Circuit"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure(CocoaError(.userCancelled))
        }
        do {
            let data = try Data(contentsOf: url)
            return .success(try validate(data: data))
        } catch {
            return .failure(error)
        }
    }

    static func validate(data: Data) throws -> TrackLayout {
        guard let layout = try? SaveStore.shared.decodeTrack(data) else {
            throw TrackCodecError.invalidJSON
        }
        guard layout.schemaVersion <= 1 else {
            throw TrackCodecError.unsupportedSchema(layout.schemaVersion)
        }
        guard !layout.pieces.isEmpty else { throw TrackCodecError.emptyTrack }
        let starts = layout.pieces.filter { $0.kind == .startFinish }.count
        if starts == 0 { throw TrackCodecError.noStartPiece }
        if starts > 1 { throw TrackCodecError.duplicateStart }
        var validated = layout
        validated.isBuiltIn = false
        let built = TrackPathBuilder.build(validated)
        guard built.isClosed else {
            throw TrackCodecError.openCircuit(built.closureError)
        }
        guard built.length >= 8 else {
            throw TrackCodecError.tooShort
        }
        return validated
    }

    static func validate(text: String) throws -> TrackLayout {
        guard let data = text.data(using: .utf8) else {
            throw TrackCodecError.invalidJSON
        }
        return try validate(data: data)
    }

    static func jsonString(for layout: TrackLayout) throws -> String {
        let data = try SaveStore.shared.encodeTrack(layout)
        return String(decoding: data, as: UTF8.self)
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Circuit" : cleaned
    }
}

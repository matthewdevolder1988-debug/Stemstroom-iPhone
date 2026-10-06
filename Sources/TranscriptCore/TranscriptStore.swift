import Foundation

public enum TranscriptStoreError: LocalizedError, Sendable {
    case directoryUnavailable(path: String, reason: String)
    case unreadableFile(filename: String, reason: String)
    case corruptFile(filename: String)
    case writeFailed(filename: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .directoryUnavailable(let path, let reason):
            return "De opslagmap ‘\(path)’ is niet beschikbaar. \(reason)"
        case .unreadableFile(let filename, let reason):
            return "De sessie ‘\(filename)’ kon niet worden gelezen. \(reason)"
        case .corruptFile(let filename):
            return "De sessie ‘\(filename)’ is beschadigd of heeft een ongeldige sessie-ID. Het bestand is behouden en wordt niet overschreven."
        case .writeFailed(let filename, let reason):
            return "De sessie ‘\(filename)’ kon niet worden opgeslagen. \(reason)"
        }
    }
}

/// Synchrone opslag; de aanroeper voert wijzigingen en saves in vaste volgorde uit.
public struct TranscriptStore: Sendable {
    private let directory: URL

    public init(directory: URL) throws {
        guard directory.isFileURL else {
            throw TranscriptStoreError.directoryUnavailable(
                path: directory.absoluteString,
                reason: "Kies een lokale bestandsmap."
            )
        }
        self.directory = directory
        do {
            #if os(iOS)
            let attributes: [FileAttributeKey: Any] = [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: directory.path)
            #else
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #endif
        } catch {
            throw TranscriptStoreError.directoryUnavailable(path: directory.path, reason: error.localizedDescription)
        }
    }

    public func save(_ document: TranscriptDocument) throws {
        let destination = fileURL(id: document.id)

        // Een corrupte vorige versie is bewijsmateriaal, geen leeg document.
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try readDocument(at: destination)
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            #if os(iOS)
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: destination.path
            )
            #else
            try data.write(to: destination, options: .atomic)
            #endif
        } catch {
            throw TranscriptStoreError.writeFailed(filename: destination.lastPathComponent, reason: error.localizedDescription)
        }
    }

    public func load(id: UUID) throws -> TranscriptDocument {
        try readDocument(at: fileURL(id: id))
    }

    public func list() throws -> [TranscriptDocument] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            throw TranscriptStoreError.directoryUnavailable(path: directory.path, reason: error.localizedDescription)
        }

        // Geen try?: één onleesbare sessie moet zichtbaar blijven voor de gebruiker.
        return try files.filter { $0.pathExtension.lowercased() == "json" }
            .map { try readDocument(at: $0) }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private func fileURL(id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func readDocument(at url: URL) throws -> TranscriptDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TranscriptStoreError.unreadableFile(filename: url.lastPathComponent, reason: error.localizedDescription)
        }

        let document: TranscriptDocument
        do {
            document = try JSONDecoder().decode(TranscriptDocument.self, from: data)
        } catch {
            throw TranscriptStoreError.corruptFile(filename: url.lastPathComponent)
        }
        let filenameID = url.deletingPathExtension().lastPathComponent
        guard UUID(uuidString: filenameID) == document.id else {
            throw TranscriptStoreError.corruptFile(filename: url.lastPathComponent)
        }
        return document
    }
}

import Foundation

public enum TranscriptStatus: String, Codable, Sendable {
    case recording
    case interrupted
    case completed
}

public struct TranscriptSegment: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var text: String
    public var isFinal: Bool
    public var isNotice: Bool

    public init(id: String, text: String, isFinal: Bool, isNotice: Bool = false) {
        self.id = id
        self.text = text
        self.isFinal = isFinal
        self.isNotice = isNotice
    }
}

public struct TranscriptDocument: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var endedAt: Date?
    public var status: TranscriptStatus
    public var segments: [TranscriptSegment]

    public init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.endedAt = nil
        self.status = .recording
        self.segments = []
    }

    /// Bevat ook onderbrekingen: gekopieerde tekst verbergt geen ontbrekende opname.
    public var plainText: String {
        segments.map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    /// Een stabiele passage-ID voorkomt duplicaten door voorlopige of herhaalde resultaten.
    public mutating func apply(
        text: String,
        segmentID: String,
        isFinal: Bool,
        at: Date = Date()
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let index = segments.firstIndex(where: { $0.id == segmentID }) {
            guard !segments[index].isNotice else { return }
            guard !segments[index].isFinal || isFinal else { return }
            guard segments[index].text != text || segments[index].isFinal != isFinal else { return }
            segments[index].text = text
            segments[index].isFinal = isFinal
        } else {
            segments.append(TranscriptSegment(id: segmentID, text: text, isFinal: isFinal))
        }
        updatedAt = max(updatedAt, at)
    }

    public mutating func markInterruption(reason: String, at: Date = Date()) {
        guard status != .completed else { return }
        let description = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = description.isEmpty ? "Opname onderbroken." : description
        segments.append(TranscriptSegment(
            id: "notice-\(UUID().uuidString)",
            text: "[Onderbreking: \(message)]",
            isFinal: true,
            isNotice: true
        ))
        status = .interrupted
        updatedAt = max(updatedAt, at)
    }

    public mutating func resume(at: Date = Date()) {
        guard status == .interrupted else { return }
        status = .recording
        updatedAt = max(updatedAt, at)
    }

    public mutating func finish(at: Date = Date()) {
        guard status != .completed else { return }
        status = .completed
        endedAt = at
        updatedAt = max(updatedAt, at)
    }
}

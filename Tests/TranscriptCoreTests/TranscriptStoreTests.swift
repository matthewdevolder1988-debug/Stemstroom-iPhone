import Foundation
import Testing
@testable import TranscriptCore

struct TranscriptStoreTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000.125)

    @Test("Opslag bewaart tekst, Unicode, meldingen en tijden exact")
    func documentRoundTrip() throws {
        try withTemporaryStore { store, _ in
            var document = TranscriptDocument(createdAt: start)
            document.apply(text: "Één patiënt, twee ideeën. 👋", segmentID: "1", isFinal: true, at: start)
            document.markInterruption(reason: "Telefoongesprek", at: start.addingTimeInterval(20))
            document.resume(at: start.addingTimeInterval(45))
            document.apply(text: "Na het gesprek.", segmentID: "2", isFinal: true, at: start.addingTimeInterval(50))
            document.finish(at: start.addingTimeInterval(60))
            try store.save(document)

            let loaded = try store.load(id: document.id)
            #expect(loaded == document)
            #expect(loaded.plainText.contains("Telefoongesprek"))
        }
    }

    @Test("Een nieuwe store herstelt een nog niet gestopte sessie")
    func unfinishedSessionSurvivesReopening() throws {
        try withTemporaryStore { store, directory in
            var document = TranscriptDocument(createdAt: start)
            document.apply(text: "Ook de voorlopige woorden blijven bewaard", segmentID: "1", isFinal: false, at: start)
            try store.save(document)
            let reopened = try TranscriptStore(directory: directory)
            let recovered = try reopened.load(id: document.id)

            #expect(recovered == document)
            #expect(recovered.status == .recording)
            #expect(recovered.segments.first?.isFinal == false)
        }
    }

    @Test("Sessies staan op aanmaaktijd van nieuw naar oud")
    func sessionsAreSortedByCreation() throws {
        try withTemporaryStore { store, _ in
            var older = TranscriptDocument(createdAt: start)
            let newer = TranscriptDocument(createdAt: start.addingTimeInterval(100))
            let middle = TranscriptDocument(createdAt: start.addingTimeInterval(50))
            older.apply(text: "Later bewerkt.", segmentID: "1", isFinal: true, at: start.addingTimeInterval(200))
            try store.save(newer)
            try store.save(older)
            try store.save(middle)

            let documents = try store.list()
            #expect(documents.map(\.id) == [newer.id, middle.id, older.id])
        }
    }

    @Test("Een beschadigd bestand in de lijst geeft een zichtbare fout met bestandsnaam")
    func corruptFileIsReportedByList() throws {
        try withTemporaryStore { store, directory in
            try store.save(TranscriptDocument(createdAt: start))
            let corruptURL = directory.appendingPathComponent("beschadigde-sessie.json")
            try Data("{onvolledig".utf8).write(to: corruptURL)

            do {
                _ = try store.list()
                Issue.record("De lijst negeerde een beschadigde sessie.")
            } catch {
                #expect(error.localizedDescription.contains("beschadigde-sessie.json"))
                #expect(error.localizedDescription.contains("beschadigd"))
            }
        }
    }

    @Test("Autosave overschrijft nooit een beschadigd bestaand bestand")
    func corruptDestinationIsNeverOverwritten() throws {
        try withTemporaryStore { store, directory in
            let document = TranscriptDocument(createdAt: start)
            let destination = directory.appendingPathComponent("\(document.id.uuidString).json")
            let evidence = Data("{\"onvolledig\": ".utf8)
            try evidence.write(to: destination)

            do {
                try store.save(document)
                Issue.record("Een beschadigde sessie werd overschreven.")
            } catch {
                #expect(error.localizedDescription.contains(destination.lastPathComponent))
            }
            let survivingData = try Data(contentsOf: destination)
            #expect(survivingData == evidence)
        }
    }

    @Test("Een beschadigde sessie kan niet als leeg document worden geladen")
    func corruptFileCannotBeLoaded() throws {
        try withTemporaryStore { store, directory in
            let id = UUID()
            let destination = directory.appendingPathComponent("\(id.uuidString).json")
            try Data("{}".utf8).write(to: destination)

            do {
                _ = try store.load(id: id)
                Issue.record("Een ongeldig document werd geladen.")
            } catch {
                #expect(error.localizedDescription.contains(destination.lastPathComponent))
                #expect(error.localizedDescription.contains("beschadigd"))
            }
        }
    }

    @Test("Een nieuwe sessie en latere autosave wijzigen vorige sessies niet")
    func sessionsRemainIsolated() throws {
        try withTemporaryStore { store, _ in
            var first = TranscriptDocument(createdAt: start)
            first.apply(text: "Eerste sessie.", segmentID: "same-segment-id", isFinal: true, at: start)
            first.finish(at: start.addingTimeInterval(60))
            try store.save(first)

            var second = TranscriptDocument(createdAt: start.addingTimeInterval(100))
            second.apply(text: "Tweede", segmentID: "same-segment-id", isFinal: false, at: start.addingTimeInterval(101))
            try store.save(second)
            second.apply(text: "Tweede sessie bijgewerkt.", segmentID: "same-segment-id", isFinal: true, at: start.addingTimeInterval(102))
            try store.save(second)

            let reloadedFirst = try store.load(id: first.id)
            let reloadedSecond = try store.load(id: second.id)
            let all = try store.list()
            #expect(reloadedFirst == first)
            #expect(reloadedSecond == second)
            #expect(all.count == 2)
        }
    }

    @Test("Herhaalde autosave laat één leesbaar sessiebestand achter")
    func repeatedSavesKeepOneFile() throws {
        try withTemporaryStore { store, directory in
            var document = TranscriptDocument(createdAt: start)
            for number in 1...10 {
                document.apply(text: "Versie \(number)", segmentID: "1", isFinal: false, at: start.addingTimeInterval(Double(number)))
                try store.save(document)
            }
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let loaded = try store.load(id: document.id)

            #expect(files.count == 1)
            #expect(loaded.plainText == "Versie 10")
            #expect(loaded.segments.count == 1)
        }
    }

    @Test("Een document met een andere sessie-ID wordt niet overschreven")
    func mismatchedDocumentIdentityIsProtected() throws {
        try withTemporaryStore { store, directory in
            let first = TranscriptDocument(createdAt: start)
            let second = TranscriptDocument(createdAt: start.addingTimeInterval(10))
            try store.save(first)
            let originalURL = directory.appendingPathComponent("\(first.id.uuidString).json")
            let wrongURL = directory.appendingPathComponent("\(second.id.uuidString).json")
            try FileManager.default.copyItem(at: originalURL, to: wrongURL)
            let evidence = try Data(contentsOf: wrongURL)

            do {
                try store.save(second)
                Issue.record("Een document met een afwijkende sessie-ID werd overschreven.")
            } catch {
                #expect(error.localizedDescription.contains(wrongURL.lastPathComponent))
            }
            let survivingData = try Data(contentsOf: wrongURL)
            #expect(survivingData == evidence)
        }
    }

    private func withTemporaryStore(_ body: (TranscriptStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StemstroomTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TranscriptStore(directory: directory)
        try body(store, directory)
    }
}

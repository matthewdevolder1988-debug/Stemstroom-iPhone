import Foundation
import Testing
@testable import TranscriptCore

struct TranscriptDocumentTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Voorlopige tekst wordt vervangen zonder dubbele passages")
    func provisionalTextIsReplaced() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Een begin", segmentID: "1", isFinal: false, at: start)
        document.apply(text: "Een begin van de bespreking.", segmentID: "1", isFinal: true, at: start.addingTimeInterval(2))

        #expect(document.segments.count == 1)
        #expect(document.plainText == "Een begin van de bespreking.")
        #expect(document.segments.first?.isFinal == true)
    }

    @Test("Een oud voorlopig resultaat overschrijft geen finale passage")
    func staleProvisionalResultIsIgnored() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Definitieve tekst.", segmentID: "1", isFinal: true, at: start)
        let finalized = document
        document.apply(text: "Definit", segmentID: "1", isFinal: false, at: start.addingTimeInterval(9))

        #expect(document == finalized)
    }

    @Test("Een herhaald finaal resultaat blijft volledig idempotent")
    func repeatedFinalResultIsIdempotent() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Dit blijft één passage.", segmentID: "1", isFinal: true, at: start)
        let finalized = document
        document.apply(text: "Dit blijft één passage.", segmentID: "1", isFinal: true, at: start.addingTimeInterval(10))

        #expect(document == finalized)
    }

    @Test("Verschillende passage-ID's behouden hun eerste volgorde")
    func segmentIdentityPreservesOrder() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Eerste", segmentID: "first", isFinal: false, at: start)
        document.apply(text: "Tweede.", segmentID: "second", isFinal: true, at: start)
        document.apply(text: "Eerste zin.", segmentID: "first", isFinal: true, at: start)

        #expect(document.plainText == "Eerste zin.\n\nTweede.")
        #expect(document.segments.map(\.id) == ["first", "second"])
    }

    @Test("Lege herkenningsresultaten wissen geen bestaande tekst")
    func emptyRecognitionIsIgnored() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Bewaar deze woorden.", segmentID: "1", isFinal: false, at: start)
        let saved = document
        document.apply(text: " \n\t", segmentID: "1", isFinal: true, at: start.addingTimeInterval(1))
        document.apply(text: "", segmentID: "2", isFinal: false, at: start)

        #expect(document == saved)
    }

    @Test("Kopieerbare tekst bewaart Nederlandse accenten en Unicode")
    func unicodeTextIsPreserved() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Één geëngageerde coördinator zei: ‘Goeiemorgen!’ 👋", segmentID: "1", isFinal: true, at: start)
        document.apply(text: "IJsselmeer, café en € 12,50.", segmentID: "2", isFinal: true, at: start)

        #expect(document.plainText == "Één geëngageerde coördinator zei: ‘Goeiemorgen!’ 👋\n\nIJsselmeer, café en € 12,50.")
    }

    @Test("Een onderbreking bewaart woorden en voegt een zichtbare melding toe")
    func interruptionPreservesText() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Voor de oproep.", segmentID: "1", isFinal: true, at: start)
        document.markInterruption(reason: "Telefoongesprek", at: start.addingTimeInterval(15))

        #expect(document.status == .interrupted)
        #expect(document.endedAt == nil)
        #expect(document.segments.count == 2)
        #expect(document.segments.last?.isNotice == true)
        #expect(document.plainText.contains("Voor de oproep."))
        #expect(document.plainText.contains("Telefoongesprek"))
    }

    @Test("Hervatten bewaart de melding en dezelfde sessie")
    func resumptionRetainsInterruptionNotice() {
        var document = TranscriptDocument(createdAt: start)
        let sessionID = document.id
        document.markInterruption(reason: "Microfoon tijdelijk niet beschikbaar", at: start)
        let interruptedSegments = document.segments
        document.resume(at: start.addingTimeInterval(30))

        #expect(document.id == sessionID)
        #expect(document.status == .recording)
        #expect(document.endedAt == nil)
        #expect(document.segments == interruptedSegments)
        #expect(document.updatedAt == start.addingTimeInterval(30))
    }

    @Test("Stop zet de eindtijd één keer")
    func stopSetsAnUnchangingEndTime() {
        var document = TranscriptDocument(createdAt: start)
        document.finish(at: start.addingTimeInterval(60))
        document.finish(at: start.addingTimeInterval(90))

        #expect(document.status == .completed)
        #expect(document.endedAt == start.addingTimeInterval(60))
        #expect(document.updatedAt == start.addingTimeInterval(60))
    }

    @Test("Een late systeemmelding herstart geen gestopte sessie")
    func completedSessionDoesNotRestart() {
        var document = TranscriptDocument(createdAt: start)
        document.finish(at: start.addingTimeInterval(60))
        let completed = document
        document.markInterruption(reason: "Late melding", at: start.addingTimeInterval(65))
        document.resume(at: start.addingTimeInterval(70))

        #expect(document == completed)
    }

    @Test("De laatste finale tekst mag na Stop nog aankomen")
    func finalResultAfterStopIsPreserved() {
        var document = TranscriptDocument(createdAt: start)
        document.apply(text: "Het laatste", segmentID: "1", isFinal: false, at: start)
        document.finish(at: start.addingTimeInterval(60))
        document.apply(text: "Het laatste woord.", segmentID: "1", isFinal: true, at: start.addingTimeInterval(61))

        #expect(document.status == .completed)
        #expect(document.endedAt == start.addingTimeInterval(60))
        #expect(document.plainText == "Het laatste woord.")
        #expect(document.segments.count == 1)
    }

    @Test("Drie uur en vijftien minuten tekst heeft geen sessielimiet")
    func threeHoursFifteenMinutesOfSegments() {
        var document = TranscriptDocument(createdAt: start)
        for number in 1...2_340 {
            let instant = start.addingTimeInterval(Double(number * 5))
            document.apply(text: "Voorlopig \(number)", segmentID: "\(number)", isFinal: false, at: instant)
            document.apply(text: "Passage \(number).", segmentID: "\(number)", isFinal: true, at: instant)
        }

        #expect(document.status == .recording)
        #expect(document.endedAt == nil)
        #expect(document.segments.count == 2_340)
        #expect(document.segments.allSatisfy(\.isFinal))
        #expect(Set(document.segments.map(\.id)).count == 2_340)
        #expect(document.plainText.components(separatedBy: "\n\n").count == 2_340)
        #expect(document.plainText.hasPrefix("Passage 1.\n\nPassage 2."))
        #expect(document.plainText.hasSuffix("Passage 2340."))
        #expect(document.updatedAt.timeIntervalSince(start) == 11_700)
        document.finish(at: start.addingTimeInterval(11_700))
        #expect(document.endedAt?.timeIntervalSince(start) == 11_700)
    }
}

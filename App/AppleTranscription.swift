import AVFAudio
import CoreMedia
import Speech

@MainActor
final class AppleTranscription {
    private let capture = MicrophoneCapture()
    private var analyzer: SpeechAnalyzer?
    private var inputWriter: AsyncStream<AnalyzerInput>.Continuation?
    private var feedTask: Task<String?, Never>?
    private var resultTask: Task<Void, Never>?
    private var resultFailure: String?
    private var isFinishing = false
    private let runID = UUID().uuidString

    func start(
        localeIdentifier: String,
        onText: @escaping (String, String, Bool) -> Void,
        onFailure: @escaping (String) -> Void,
        onStatus: @escaping (String) -> Void
    ) async throws {
        let requested = Locale(identifier: localeIdentifier)
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requested) else {
            throw RecordingError.message("Nederlands is niet beschikbaar voor lokale herkenning op dit toestel. Controleer iOS en de dicteertalen in Instellingen.")
        }
        let module = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        onStatus("Nederlandse spraakherkenning voorbereiden…")
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            onStatus("Nederlands taalmodel downloaden. De eerste keer is internet nodig…")
            try await installation.downloadAndInstall()
        }
        try Task.checkCancellation()
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            throw RecordingError.message("Het Nederlandse taalmodel kon niet worden voorbereid.")
        }
        let analyzer = SpeechAnalyzer(modules: [module])
        self.analyzer = analyzer
        let (inputs, writer) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingOldest(64))
        inputWriter = writer

        resultTask = Task { [weak self] in
            var passage = 0
            var finalizedThrough = CMTime.negativeInfinity
            do {
                for try await result in module.results {
                    guard let self else { return }
                    let end = CMTimeRangeGetEnd(result.range)
                    guard CMTimeCompare(end, finalizedThrough) > 0 else { continue }
                    // Eén voorlopige passage wordt vervangen tot de definitieve versie.
                    // De ID hangt niet af van bijgestelde spraaktimestamps.
                    onText(self.runID + ":" + String(passage), String(result.text.characters), result.isFinal)
                    if result.isFinal { finalizedThrough = end; passage += 1 }
                }
                if self?.isFinishing == false { onFailure("De spraakherkenning is onverwacht onderbroken.") }
            } catch {
                self?.resultFailure = error.localizedDescription
                if self?.isFinishing == false { onFailure("Spraakherkenning: \(error.localizedDescription)") }
            }
        }

        do {
            try await analyzer.start(inputSequence: inputs)
            try Task.checkCancellation()
            let (buffers, sourceFormat) = try capture.start()
            let converter = try PCMConverter(from: sourceFormat, to: format)
            // Conversie staat los van schermupdates en lokale documentopslag.
            feedTask = Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    for try await buffer in buffers {
                        if let converted = try converter.convert(buffer),
                           case .dropped = writer.yield(AnalyzerInput(buffer: converted)) {
                            throw RecordingError.message("De spraakherkenning loopt achter. Een deel van de audio ontbreekt.")
                        }
                    }
                    for tail in try converter.drain() {
                        if case .dropped = writer.yield(AnalyzerInput(buffer: tail)) {
                            throw RecordingError.message("De laatste audio paste niet meer in de herkenningswachtrij.")
                        }
                    }
                } catch {
                    let message = error.localizedDescription
                    let owner = self
                    await MainActor.run {
                        if owner?.isFinishing == false { onFailure(message) }
                    }
                    writer.finish()
                    return message
                }
                writer.finish()
                return nil
            }
        } catch {
            await cancel()
            throw error
        }
    }

    /// Wacht op de laatste woorden voordat de resultaattaak wordt opgeruimd.
    func finish() async throws {
        isFinishing = true
        capture.stop()
        let feedFailure = await feedTask?.value
        inputWriter?.finish()
        if let analyzer {
            do { try await analyzer.finalizeAndFinishThroughEndOfInput() }
            catch { await cancel(); throw error }
        }
        await resultTask?.value
        releaseTasks()
        if let failure = feedFailure ?? resultFailure { throw RecordingError.message(failure) }
    }

    func cancel() async {
        isFinishing = true
        capture.stop()
        inputWriter?.finish()
        feedTask?.cancel()
        if let analyzer { await analyzer.cancelAndFinishNow() }
        resultTask?.cancel()
        _ = await feedTask?.value
        await resultTask?.value
        releaseTasks()
    }

    private func releaseTasks() {
        feedTask = nil
        resultTask = nil
        inputWriter = nil
        analyzer = nil
    }
}

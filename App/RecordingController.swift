import AVFAudio
import Combine
import Speech
import UIKit

@MainActor
final class RecordingController: ObservableObject {
    enum State { case idle, preparing, recording, interrupted, stopping }

    @Published private(set) var state: State = .idle
    @Published private(set) var document: TranscriptDocument?
    @Published private(set) var history: [TranscriptDocument] = []
    @Published private(set) var status = "Klaar om te luisteren"
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasUnsavedChanges = false
    @Published var localeIdentifier = "nl-BE"

    private var store: TranscriptStore?
    private var pipeline: AppleTranscription?
    private var operation: Task<Void, Never>?
    private var preparation: Task<Void, Error>?
    private var requestedRecording = false
    private var observers: [NSObjectProtocol] = []
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private var generation = UUID()

    var isSessionOpen: Bool { requestedRecording }
    var canStart: Bool { store != nil && !requestedRecording && state != .stopping && !hasUnsavedChanges }
    var canResume: Bool { requestedRecording && state == .interrupted }
    var hasRecoverableSession: Bool { document != nil && document?.status != .completed }

    init() {
        do {
            let base = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let store = try TranscriptStore(directory: base.appendingPathComponent("Transcripties", isDirectory: true))
            self.store = store
            history = try store.list()
            if var last = history.first {
                if last.status != .completed {
                    last.markInterruption(reason: "De app is opnieuw geopend. Audio tijdens de onderbreking is niet opgenomen.")
                    try store.save(last)
                    status = "Vorige tekst hersteld. Tik op Hervat opname."
                }
                document = last
            }
        } catch {
            errorMessage = "Opgeslagen tekst lezen: \(error.localizedDescription)"
        }
        observeAudioSession()
    }

    func start(newSession: Bool = false) {
        guard canStart else { return }
        requestedRecording = true
        errorMessage = nil
        state = .preparing
        if newSession || document?.status == .completed { document = nil }
        enqueue { [weak self] in await self?.beginRecording() }
    }

    func resume() {
        guard canResume else { return }
        state = .preparing
        enqueue { [weak self] in await self?.beginRecording() }
    }

    func stop() {
        guard requestedRecording else { return }
        requestedRecording = false
        state = .stopping
        status = "Laatste woorden opslaan…"
        preparation?.cancel()
        beginBackgroundFinalization()
        enqueue { [weak self] in
            guard let self else { return }
            await self.closePipeline()
            self.document?.finish()
            let saved = self.persist()
            self.state = .idle
            self.status = saved ? "Opname gestopt" : "Opname gestopt · tekst nog niet opgeslagen"
            self.refreshHistory()
            self.endBackgroundFinalization()
        }
    }

    func select(_ saved: TranscriptDocument) {
        guard !requestedRecording, state == .idle, !hasUnsavedChanges else { return }
        document = saved
        status = saved.status == .completed ? "Opgeslagen transcriptie" : "Deze sessie kan worden hervat"
    }

    func refreshHistory() {
        do { history = try store?.list() ?? [] }
        catch { errorMessage = "Transcripties laden: \(error.localizedDescription)" }
    }

    func copyAll() {
        guard let text = document?.plainText, !text.isEmpty else { return }
        UIPasteboard.general.string = text
    }

    func retrySave() {
        if persist() {
            errorMessage = nil
            if state == .idle { status = "Tekst opgeslagen" }
            refreshHistory()
        }
    }

    private func enqueue(_ action: @escaping @MainActor () async -> Void) {
        let preceding = operation
        operation = Task {
            await preceding?.value
            await action()
        }
    }

    private func beginRecording() async {
        guard requestedRecording, pipeline == nil else { return }
        state = .preparing
        status = "Microfoon voorbereiden…"
        do {
            guard await AVAudioApplication.requestRecordPermission() else {
                throw RecordingError.message("Geef Stemstroom toegang tot de microfoon via Instellingen > Privacy en beveiliging > Microfoon.")
            }
            let speechAllowed = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            guard speechAllowed else {
                throw RecordingError.message("Geef Stemstroom toegang tot spraakherkenning via Instellingen > Privacy en beveiliging > Spraakherkenning.")
            }
            guard requestedRecording else { return }
            if document == nil { document = TranscriptDocument() }
            document?.resume()
            guard persist() else {
                throw RecordingError.message("De transcriptie kan niet veilig worden opgeslagen. Maak opslagruimte vrij en probeer opnieuw.")
            }
            let pipeline = AppleTranscription()
            self.pipeline = pipeline
            let token = UUID()
            generation = token
            let job = Task { [weak self] in
                guard let self else { return }
                try await pipeline.start(
                    localeIdentifier: self.localeIdentifier,
                    onText: { [weak self] id, text, isFinal in
                        guard let self, self.generation == token else { return }
                        self.document?.apply(text: text, segmentID: id, isFinal: isFinal)
                        if !self.persist(), self.state == .recording || self.state == .preparing {
                            self.interrupt(reason: "Opslaan mislukt. De zichtbare tekst staat nog in het geheugen; kopieer deze nu.", autoResume: false)
                        }
                    },
                    onFailure: { [weak self] reason in
                        guard let self, self.generation == token else { return }
                        self.interrupt(reason: reason, autoResume: true)
                    },
                    onStatus: { [weak self] message in
                        guard let self, self.generation == token, self.requestedRecording, self.state == .preparing else { return }
                        self.status = message
                    }
                )
            }
            preparation = job
            try await job.value
            preparation = nil
            guard requestedRecording, state == .preparing else { return }
            state = .recording
            status = "Luistert · ook met vergrendeld scherm"
        } catch {
            preparation = nil
            await pipeline?.cancel()
            pipeline = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            if requestedRecording {
                state = .interrupted
                status = "Opname onderbroken"
                errorMessage = error.localizedDescription
                document?.markInterruption(reason: error.localizedDescription)
                persist()
            }
        }
    }

    @discardableResult
    private func persist() -> Bool {
        guard let store, let document else { return false }
        hasUnsavedChanges = true
        do { try store.save(document); hasUnsavedChanges = false; return true }
        catch { errorMessage = "Opslaan mislukt: \(error.localizedDescription)"; return false }
    }

    private func closePipeline() async {
        guard let pipeline else { return }
        do { try await pipeline.finish() }
        catch {
            document?.markInterruption(reason: "De laatste woorden konden niet worden afgerond: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        self.pipeline = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        catch { /* Een telefoongesprek kan de sessie al gedeactiveerd hebben. */ }
    }

    private func interrupt(reason: String, autoResume: Bool) {
        guard requestedRecording, state == .recording || state == .preparing else { return }
        state = .interrupted
        status = "Onderbroken · tekst blijft bewaard"
        preparation?.cancel()
        beginBackgroundFinalization()
        enqueue { [weak self] in
            guard let self else { return }
            defer { self.endBackgroundFinalization() }
            await self.closePipeline()
            self.document?.markInterruption(reason: reason)
            self.persist()
            guard self.requestedRecording else { return }
            self.state = .interrupted
            if autoResume {
                // Geen sessielimiet: deze korte pauze voorkomt een snelle herstartlus.
                try? await Task.sleep(for: .seconds(1))
                if self.requestedRecording { await self.beginRecording() }
            }
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                if type == .began {
                    self.interrupt(reason: "iOS heeft de microfoon tijdelijk overgenomen, bijvoorbeeld voor een telefoongesprek. Audio tijdens deze onderbreking ontbreekt.", autoResume: false)
                } else if let optionsValue,
                          AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume),
                          self.requestedRecording {
                    self.enqueue { [weak self] in await self?.beginRecording() }
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let reasonValue, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                      reason == .oldDeviceUnavailable || reason == .newDeviceAvailable else { return }
                self?.interrupt(reason: "De microfoonverbinding is gewijzigd. Een korte audio-onderbreking is mogelijk.", autoResume: true)
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.interrupt(reason: "iOS heeft de audiodienst opnieuw gestart. Tik op Hervat opname om verder te gaan.", autoResume: false)
            }
        })
    }

    private func beginBackgroundFinalization() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Laatste woorden bewaren") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.persist()
                self.endBackgroundFinalization()
            }
        }
    }

    private func endBackgroundFinalization() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}

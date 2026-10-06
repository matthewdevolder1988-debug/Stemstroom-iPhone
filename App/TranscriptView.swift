import SwiftUI

struct TranscriptView: View {
    @ObservedObject var recorder: RecordingController
    @State private var showsHistory = false
    @State private var followsText = true
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                Divider()
                transcript
            }
            .navigationTitle("Stemstroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Opgeslagen", systemImage: "clock.arrow.circlepath") {
                        recorder.refreshHistory()
                        showsHistory = true
                    }
                    .disabled(recorder.isSessionOpen || recorder.state == .stopping || recorder.hasUnsavedChanges)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .sheet(isPresented: $showsHistory) { history }
        }
        .tint(.teal)
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(recorder.status, systemImage: recorder.state == .recording ? "mic.fill" : "waveform")
                    .font(.subheadline)
                    .foregroundStyle(recorder.state == .recording ? Color.primary : Color.secondary)
                Spacer(minLength: 12)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(elapsed(at: timeline.date))
                        .font(.system(.subheadline, design: .monospaced))
                        .monospacedDigit()
                        .accessibilityLabel("Sessieduur \(elapsed(at: timeline.date))")
                }
            }
            Picker("Nederlands", selection: $recorder.localeIdentifier) {
                Text("Nederlands · België").tag("nl-BE")
                Text("Nederlands · Nederland").tag("nl-NL")
            }
            .pickerStyle(.menu)
            .disabled(recorder.isSessionOpen || recorder.state == .stopping)
            .frame(minHeight: 44, alignment: .leading)

            if let error = recorder.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            if recorder.hasUnsavedChanges {
                Button("Opnieuw opslaan", systemImage: "arrow.clockwise") { recorder.retrySave() }
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let document = recorder.document, !document.segments.isEmpty {
                        ForEach(document.segments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                if segment.isNotice {
                                    Label(segment.text, systemImage: "exclamationmark.circle")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(segment.text)
                                        .font(.body)
                                        .lineSpacing(5)
                                        .textSelection(.enabled)
                                    if !segment.isFinal {
                                        Text("Voorlopige tekst")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("Spreek. Je tekst groeit mee.", systemImage: "waveform")
                        } description: {
                            Text("Tik op Start opname. Ook tijdens stilte en met vergrendeld scherm blijft de sessie open tot je op Stop tikt. De tekst blijft op deze iPhone.")
                        }
                        .padding(.top, 32)
                    }
                    Color.clear.frame(height: 1).id("latest")
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: recorder.document?.updatedAt) { _, _ in
                if followsText { proxy.scrollTo("latest", anchor: .bottom) }
                copied = false
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Divider()
            Toggle("Nieuwe tekst volgen", isOn: $followsText)
                .font(.subheadline)
                .frame(minHeight: 44)

            if recorder.canResume {
                Button("Hervat opname", systemImage: "mic.fill") { recorder.resume() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { primaryButton; copyButton }
                VStack(spacing: 12) { primaryButton; copyButton }
            }
            if !recorder.isSessionOpen, recorder.hasRecoverableSession, recorder.state == .idle {
                Button("Begin een nieuwe opname") { recorder.start(newSession: true) }
                    .frame(minHeight: 44)
                    .disabled(!recorder.canStart)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    private var primaryButton: some View {
        Button {
            if recorder.isSessionOpen { recorder.stop() }
            else { recorder.start() }
        } label: {
            Label(
                recorder.state == .stopping ? "Opslaan…" : recorder.isSessionOpen ? "Stop opname" : recorder.hasRecoverableSession ? "Hervat opname" : "Start opname",
                systemImage: recorder.isSessionOpen ? "stop.fill" : "mic.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 28)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.borderedProminent)
        .tint(recorder.isSessionOpen ? .red : .teal)
        .controlSize(.large)
        .disabled(!recorder.isSessionOpen && !recorder.canStart)
    }

    private var copyButton: some View {
        Button {
            recorder.copyAll()
            copied = true
        } label: {
            Label(copied ? "Gekopieerd" : "Kopieer alles", systemImage: copied ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity, minHeight: 28)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(recorder.document?.plainText.isEmpty != false)
        .accessibilityHint("Kopieert ook de voorlopige tekst en eventuele onderbrekingsmeldingen.")
    }

    private var history: some View {
        NavigationStack {
            List(recorder.history) { document in
                Button {
                    recorder.select(document)
                    showsHistory = false
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.primary)
                        Text(document.plainText.isEmpty ? "Nog geen tekst" : document.plainText)
                            .lineLimit(2)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .overlay { if recorder.history.isEmpty { ContentUnavailableView("Nog geen transcripties", systemImage: "doc.text") } }
            .navigationTitle("Opgeslagen tekst")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Sluiten") { showsHistory = false } } }
        }
    }

    private func elapsed(at now: Date) -> String {
        guard let document = recorder.document else { return "00:00:00" }
        let end = document.endedAt ?? (recorder.isSessionOpen ? now : document.updatedAt)
        let seconds = max(0, Int(end.timeIntervalSince(document.createdAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}

import SwiftUI

@main
struct StemstroomApp: App {
    @StateObject private var recorder = RecordingController()

    var body: some Scene {
        WindowGroup { TranscriptView(recorder: recorder) }
    }
}

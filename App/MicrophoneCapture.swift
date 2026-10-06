import AVFAudio
import Foundation

enum RecordingError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

/// De tap kopieert buffers: AVAudioEngine mag zijn eigen buffer meteen hergebruiken.
/// Begrensde wachtrijen voorkomen dat een sessie van uren al haar audio vasthoudt.
final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private var continuation: AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation?
    private var tapInstalled = false

    func start() throws -> (AsyncThrowingStream<AVAudioPCMBuffer, Error>, AVAudioFormat) {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw RecordingError.message("De microfoon levert momenteel geen audio. Probeer opnieuw.")
        }

        let (stream, writer) = AsyncThrowingStream<AVAudioPCMBuffer, Error>.makeStream(
            bufferingPolicy: .bufferingOldest(64)
        )
        continuation = writer
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                writer.finish(throwing: RecordingError.message("Onvoldoende geheugen voor de microfoonbuffer."))
                return
            }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
            let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for index in 0..<source.count {
                guard let from = source[index].mData, let to = target[index].mData else { continue }
                memcpy(to, from, Int(source[index].mDataByteSize))
            }
            if case .dropped = writer.yield(copy) {
                writer.finish(throwing: RecordingError.message("De verwerking kon de microfoon niet bijhouden. Er is een audiogat ontstaan."))
            }
        }
        tapInstalled = true
        engine.prepare()
        do { try engine.start() }
        catch { stop(); throw error }
        return (stream, format)
    }

    func stop() {
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        continuation?.finish()
        continuation = nil
    }
}

final class PCMConverter {
    private let converter: AVAudioConverter
    private let target: AVAudioFormat

    init(from source: AVAudioFormat, to target: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: source, to: target) else {
            throw RecordingError.message("Het microfoonformaat kan niet worden omgezet.")
        }
        self.converter = converter
        self.target = target
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * target.sampleRate / input.format.sampleRate)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw RecordingError.message("De audioconversie heeft onvoldoende geheugen.")
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        if let conversionError { throw conversionError }
        guard status != .error else { throw RecordingError.message("De audioconversie is onderbroken.") }
        return output.frameLength > 0 ? output : nil
    }

    /// Leeg ook de resampler; anders kan Stop de laatste audiomonsters afknippen.
    func drain() throws -> [AVAudioPCMBuffer] {
        var remaining: [AVAudioPCMBuffer] = []
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 4096) else {
                throw RecordingError.message("De laatste audio kon niet worden afgerond.")
            }
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
                inputStatus.pointee = .endOfStream
                return nil
            }
            if let conversionError { throw conversionError }
            if status == .error { throw RecordingError.message("De laatste audio kon niet worden omgezet.") }
            if output.frameLength > 0 { remaining.append(output) }
            if status == .endOfStream || output.frameLength == 0 { return remaining }
        }
    }
}

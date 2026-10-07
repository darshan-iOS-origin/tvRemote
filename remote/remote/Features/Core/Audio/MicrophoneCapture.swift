//
//  MicrophoneCapture.swift
//  tvRemoteDemo
//
//  Records the microphone as 16-bit, 8 kHz, mono PCM, the audio an Android / Google TV expects for
//  its voice feature (androidtvremote2's `remotemessage.proto`: "a sequence of 16-bit PCM, 8 kHz,
//  mono samples"). The audio goes to the TV and nowhere else. It is never stored or logged.
//
//  UNVERIFIED on a device: the conversion from the microphone's own format to 8 kHz.
//

import AVFoundation

nonisolated final class MicrophoneCapture: @unchecked Sendable {
    /// Samples per second the TV expects.
    static let sampleRate = 8000.0
    /// About half a second of audio. The TV wants chunks of 8 KB or more.
    private static let chunkBytes = 8 * 1024

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var target: AVAudioFormat?
    private var pending = Data()
    private var continuation: AsyncStream<Data>.Continuation?
    private var isRunning = false

    /// Asks for microphone access, or reports that it was already given or refused.
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Starts recording. The stream yields chunks of about 8 KB and ends after `stop()`, once the
    /// last partial chunk has been yielded. Throws `VoiceAssistantError.microphoneUnavailable`.
    func start() throws -> AsyncStream<Data> {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            throw VoiceAssistantError.microphoneUnavailable
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Self.sampleRate, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw VoiceAssistantError.microphoneUnavailable
        }

        var made: AsyncStream<Data>.Continuation?
        let stream = AsyncStream<Data> { made = $0 }
        lock.lock()
        self.converter = converter
        self.target = target
        self.continuation = made
        self.pending = Data()
        self.isRunning = true
        lock.unlock()

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            lock.lock()
            continuation?.finish()
            isRunning = false
            lock.unlock()
            throw VoiceAssistantError.microphoneUnavailable
        }
        return stream
    }

    /// Stops recording, yields what is left, and ends the stream. Safe to call more than once.
    func stop() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }
        isRunning = false
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        lock.lock()
        if !pending.isEmpty {
            continuation?.yield(pending)
            pending = Data()
        }
        continuation?.finish()
        continuation = nil
        lock.unlock()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Conversion

    /// Runs on the audio thread: converts one buffer and queues the bytes.
    private func handle(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let converter = self.converter
        let target = self.target
        lock.unlock()
        guard let converter, let target else { return }

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil, output.frameLength > 0,
              let samples = output.int16ChannelData else {
            return
        }
        let bytes = Data(bytes: samples[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)

        lock.lock()
        pending.append(bytes)
        while pending.count >= Self.chunkBytes {
            continuation?.yield(pending.prefix(Self.chunkBytes))
            pending.removeFirst(Self.chunkBytes)
        }
        lock.unlock()
    }
}

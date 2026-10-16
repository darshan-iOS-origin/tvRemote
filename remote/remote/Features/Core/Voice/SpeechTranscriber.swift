//
//  SpeechTranscriber.swift
//  tvRemoteDemo
//
//  Turns the microphone into text on the phone, with Apple's Speech framework, for TVs that have no
//  voice feature to stream audio to (Roku, Samsung, LG). Recognition is **on-device only**
//  (`requiresOnDeviceRecognition`): the audio never leaves the phone, not even to Apple. If this
//  iPhone or language has no on-device model, listening fails with `onDeviceUnavailable` and never
//  falls back to a server. Neither the audio nor the words are stored or logged.
//
//  UNVERIFIED on a device: the whole flow, and which languages have an on-device model.
//

import AVFoundation
import Speech

nonisolated final class SpeechTranscriber: @unchecked Sendable {
    /// Listening ends this long after the last new word.
    private static let silenceSeconds = 1.5
    /// How long to wait for the final result after the microphone has stopped.
    private static let finishWait = 2.0

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "tvremote.voice.speech")
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var latest = ""
    private var finished = false
    private var stopped = false
    private var captureEnded = false
    private var silenceWork: DispatchWorkItem?

    private static func requestSpeechPermission() async -> Bool {
        let prompted = SFSpeechRecognizer.authorizationStatus() == .notDetermined
        if prompted {
            PermissionLogger.triggered("Speech Recognition")
        }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        PermissionLogger.speech(status, prompted: prompted)
        return status == .authorized
    }

    /// Listens until `stop()`, a pause after speech, or `timeLimit`, and returns what was heard. The
    /// result is empty when nothing was heard. `onListening` is called once the microphone is on.
    /// Throws `VoiceAssistantError`.
    func listen(timeLimit: TimeInterval, onListening: @escaping @Sendable () -> Void) async throws -> String {
        guard await Self.requestSpeechPermission() else {
            throw VoiceAssistantError.speechDenied
        }
        guard await MicrophoneCapture.requestPermission() else {
            throw VoiceAssistantError.microphoneDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw VoiceAssistantError.onDeviceUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch {
            throw VoiceAssistantError.microphoneUnavailable
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw VoiceAssistantError.microphoneUnavailable
        }

        lock.lock()
        self.request = request
        lock.unlock()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw VoiceAssistantError.microphoneUnavailable
        }
        onListening()
        queue.asyncAfter(deadline: .now() + timeLimit) { [weak self] in self?.stop() }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            lock.lock()
            self.continuation = continuation
            let alreadyStopped = stopped
            lock.unlock()

            let created = recognizer.recognitionTask(with: request) { [weak self] result, error in
                self?.handle(result, error)
            }
            lock.lock()
            self.task = created
            lock.unlock()
            if alreadyStopped {
                endCapture()
                scheduleFinish()
            }
        }
    }

    /// Stops the microphone. The recognizer then reports what it heard. Safe to call more than once.
    func stop() {
        lock.lock()
        stopped = true
        lock.unlock()
        endCapture()
        scheduleFinish()
    }

    // MARK: - Audio and results

    private func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = self.request
        lock.unlock()
        request?.append(buffer)
    }

    private func handle(_ result: SFSpeechRecognitionResult?, _ error: Error?) {
        lock.lock()
        if let result {
            latest = result.bestTranscription.formattedString
        }
        let isFinal = result?.isFinal == true
        lock.unlock()
        if isFinal || error != nil {
            finish()
        } else if result != nil {
            scheduleSilenceStop()
        }
    }

    /// A pause after speech ends the session, so nobody has to tap Stop.
    private func scheduleSilenceStop() {
        lock.lock()
        silenceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        silenceWork = work
        lock.unlock()
        queue.asyncAfter(deadline: .now() + Self.silenceSeconds, execute: work)
    }

    private func endCapture() {
        lock.lock()
        guard !captureEnded else {
            lock.unlock()
            return
        }
        captureEnded = true
        let request = self.request
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// If the final result never comes, the last partial one is used.
    private func scheduleFinish() {
        queue.asyncAfter(deadline: .now() + Self.finishWait) { [weak self] in self?.finish() }
    }

    private func finish() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        silenceWork?.cancel()
        let continuation = self.continuation
        self.continuation = nil
        let words = latest
        let task = self.task
        lock.unlock()

        endCapture()
        task?.cancel()
        continuation?.resume(returning: words)
    }
}

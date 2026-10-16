//
//  VoiceAssistant.swift
//  tvRemoteDemo
//

import Foundation

nonisolated enum VoiceAssistantError: Error, Equatable {
    /// The user refused microphone access.
    case microphoneDenied
    /// The user refused speech recognition (TVs without a voice feature of their own).
    case speechDenied
    /// This iPhone or language has no on-device speech model, and the app never sends audio to a server.
    case onDeviceUnavailable
    /// Nothing was heard.
    case nothingHeard
    /// The microphone could not be started.
    case microphoneUnavailable
}

/// One voice session at a time, the same for every TV (Android / Google TV, Roku, Samsung, LG): the phone
/// recognises the speech itself, on the device only, and runs the words as a command or types them into the
/// TV's open text box (`VoiceCommandParser`). Audio and words are never stored or logged (only states are).
/// It talks to `ConnectionManager` only.
class VoiceAssistant {
    enum State: Equatable {
        case idle
        case starting
        case listening
    }

    /// A session you forget to stop ends by itself after this long, in seconds.
    private static let timeLimit: TimeInterval = 15

    private let connection: ConnectionManager
    private var task: Task<Void, Never>?
    private var transcriber: SpeechTranscriber?
    private var stopRequested = false

    private(set) var state = State.idle {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((State) -> Void)?
    var onFailure: ((Error) -> Void)?
    /// Called when a session finished without an error (the words ran, or the audio reached the TV).
    var onSuccess: (() -> Void)?
    /// Called with the words that were recognised, before they run. Only for TVs that use the phone's
    /// speech recognition. Show them on screen only: never log or store them.
    var onHeard: ((String) -> Void)?

    init(connection: ConnectionManager, platform: TVPlatform) {
        self.connection = connection
    }

    deinit {
        task?.cancel()
    }

    /// Starts a session, or stops the running one.
    func toggle() {
        if state == .idle {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard state == .idle else { return }
        state = .starting
        stopRequested = false
        task = Task { [weak self] in
            await self?.runDictation()
        }
    }

    /// Ends the session: listening stops and what was heard so far runs.
    func stop() {
        stopRequested = true
        transcriber?.stop()
    }

    /// Listen on the phone, then run the words.
    private func runDictation() async {
        defer {
            transcriber = nil
            state = .idle
        }
        do {
            let speech = SpeechTranscriber()
            transcriber = speech
            let words = try await speech.listen(timeLimit: Self.timeLimit) { [weak self] in
                Task { @MainActor in self?.dictationStarted() }
            }
            guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VoiceAssistantError.nothingHeard
            }
            onHeard?(words)
            // Running the command can take a moment (a channel, an app list): show the spinner.
            state = .starting
            try await connection.perform(VoiceCommandParser.parse(words))
            LoggerManager.debug("Voice: command done", category: "Voice")
            onSuccess?()
        } catch {
            LoggerManager.error("Voice: failed: \(error)", category: "Voice")
            onFailure?(error)
        }
    }

    private func dictationStarted() {
        if stopRequested {
            transcriber?.stop()
        } else {
            state = .listening
        }
    }
}

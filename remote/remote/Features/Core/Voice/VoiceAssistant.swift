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

/// One voice session at a time. On Android / Google TV the phone's microphone streams to the TV's own
/// assistant, which does the listening: nothing is recognised on the phone. On Roku, Samsung and LG,
/// which have no such feature, the phone recognises the speech itself, on the device only, and runs
/// the words as a command or types them into the TV's open text box (`VoiceCommandParser`). Audio and
/// words are never stored or logged (only states and chunk counts are). It talks to `ConnectionManager` only.
class VoiceAssistant {
    enum State: Equatable {
        case idle
        case starting
        case listening
    }

    /// A session you forget to stop ends by itself after this long, in seconds.
    private static let timeLimit: TimeInterval = 15

    private let connection: ConnectionManager
    private let streamsToTV: Bool
    private var task: Task<Void, Never>?
    private var capture: MicrophoneCapture?
    private var transcriber: SpeechTranscriber?
    private var stopRequested = false

    private(set) var state = State.idle {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((State) -> Void)?
    var onFailure: ((Error) -> Void)?
    /// Called with the words that were recognised, before they run. Only for TVs that use the phone's
    /// speech recognition. Show them on screen only: never log or store them.
    var onHeard: ((String) -> Void)?

    init(connection: ConnectionManager, platform: TVPlatform) {
        self.connection = connection
        self.streamsToTV = platform == .androidTV
    }

    deinit {
        task?.cancel()
        capture?.stop()
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
            if self?.streamsToTV == true {
                await self?.run()
            } else {
                await self?.runDictation()
            }
        }
    }

    /// Ends the session: the last bit of audio is sent first, then the TV is told it is over.
    func stop() {
        stopRequested = true
        capture?.stop()
        transcriber?.stop()
    }

    /// Roku, Samsung and LG: listen on the phone, then run the words.
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

    private func run() async {
        defer {
            capture = nil
            state = .idle
        }
        do {
            guard await MicrophoneCapture.requestPermission() else {
                throw VoiceAssistantError.microphoneDenied
            }
            let microphone = MicrophoneCapture()
            capture = microphone
            // Start recording first, so the first words are not lost while the TV gets ready.
            let audio = try microphone.start()
            LoggerManager.debug("Voice: microphone started", category: "Voice")

            let session: any VoiceSession
            do {
                session = try await connection.startVoice()
            } catch {
                microphone.stop()
                throw error
            }
            LoggerManager.debug("Voice: the TV began listening", category: "Voice")
            if stopRequested {
                microphone.stop()
            } else {
                state = .listening
            }

            let limit = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.timeLimit * 1_000_000_000))
                self?.stop()
            }
            var chunks = 0
            do {
                for await chunk in audio {
                    try await session.send(chunk)
                    chunks += 1
                }
            } catch {
                limit.cancel()
                microphone.stop()
                await session.end()
                throw error
            }
            limit.cancel()
            await session.end()
            LoggerManager.debug("Voice: session ended after \(chunks) chunks", category: "Voice")
        } catch {
            LoggerManager.error("Voice: failed: \(error)", category: "Voice")
            onFailure?(error)
        }
    }
}

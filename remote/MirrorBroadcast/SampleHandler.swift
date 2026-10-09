//
//  SampleHandler.swift
//  MirrorBroadcast
//
//  The broadcast upload extension: iOS starts it when the user taps Start Broadcast and sends it every
//  screen frame and the apps' audio. It turns them into a live stream (`HLSLiveSegmenter`), serves it on
//  Wi-Fi (`MirrorStreamServer`), and tells the app where it is (`MirrorShared`). The app then asks the TV
//  to play it over Google Cast.
//
//  The microphone is never used. Nothing is recorded to disk; only the last few seconds are kept in memory.
//

import Foundation
import os
import ReplayKit
import Security

final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    /// Segments made before the app is told: the TV's player wants a few to start from.
    private static let segmentsBeforeReady = 3

    private let log = Logger(subsystem: MirrorShared.extensionBundleID, category: "Broadcast")
    /// What the app asked for: Google Cast to a TV or the viewer page in a browser, and the quality.
    private let config = MirrorShared.readConfig()
    private let segmenter: HLSLiveSegmenter
    private let server = MirrorStreamServer()
    private let token: String
    private let lock = NSLock()
    private var port: UInt16 = 0
    private var segmentCount = 0
    private var announced = false
    private var finished = false

    override init() {
        let config = MirrorShared.readConfig()
        segmenter = HLSLiveSegmenter(quality: config.quality)
        // The viewer page's address has the short code the app already showed. A TV is told a long token.
        token = config.mode == .web && !config.webCode.isEmpty ? config.webCode : SampleHandler.randomToken()
        super.init()
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        MirrorShared.write(state: .starting, mode: config.mode)
        log.info("Broadcast started")

        segmenter.onSegment = { [weak self] count in
            guard let self else { return }
            self.lock.lock()
            self.segmentCount = count
            self.lock.unlock()
            self.announceIfReady()
        }
        segmenter.onFailure = { [weak self] in
            // Called on the segmenter's own queue, which `stop()` waits for: leave it first.
            DispatchQueue.global().async {
                self?.fail("Screen mirroring stopped because the screen could not be encoded. Please try again.")
            }
        }
        segmenter.start()

        let isWeb = config.mode == .web
        server.start(
            token: token,
            segmenter: segmenter,
            preferredPort: isWeb ? MirrorShared.preferredWebPort : nil,
            servesViewerPage: isWeb
        ) { [weak self] port in
            guard let self else { return }
            guard let port else {
                self.fail("Connect this iPhone to Wi-Fi, on the same network as the TV, then try again.")
                return
            }
            self.lock.lock()
            self.port = port
            self.lock.unlock()
            self.announceIfReady()
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            segmenter.appendVideo(sampleBuffer)
        case .audioApp:
            segmenter.appendAudio(sampleBuffer)
        case .audioMic:
            break
        @unknown default:
            break
        }
    }

    override func broadcastFinished() {
        log.info("Broadcast finished")
        shutDown(state: .stopped)
    }

    // MARK: - Private

    /// Tells the app once both the server and the first segments are ready.
    private func announceIfReady() {
        lock.lock()
        let ready = !announced && !finished && port != 0 && segmentCount >= Self.segmentsBeforeReady
        if ready { announced = true }
        let port = self.port
        lock.unlock()
        guard ready else { return }
        MirrorShared.write(state: .ready, port: port, token: token, mode: config.mode)
        MirrorShared.post(MirrorShared.readyNotification)
        log.info("Stream ready")
    }

    private func fail(_ message: String) {
        guard shutDown(state: .failed) else { return }
        finishBroadcastWithError(NSError(
            domain: MirrorShared.extensionBundleID,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        ))
    }

    /// Stops everything once. Returns false if it was already stopped.
    @discardableResult
    private func shutDown(state: MirrorShared.State) -> Bool {
        lock.lock()
        let first = !finished
        finished = true
        lock.unlock()
        guard first else { return false }
        server.stop()
        segmenter.stop()
        MirrorShared.write(state: state, mode: config.mode)
        MirrorShared.post(MirrorShared.stoppedNotification)
        return true
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            // Never serve under a predictable address.
            bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

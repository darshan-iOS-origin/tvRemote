//
//  MicrophonePermission.swift
//  tvRemoteDemo
//
//  Asks for microphone access, which the phone's speech recognition needs for voice control.
//

import AVFoundation

nonisolated enum MicrophonePermission {
    /// Asks for microphone access, or reports that it was already given or refused.
    static func request() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let prompted = session.recordPermission == .undetermined
        if prompted {
            PermissionLogger.triggered("Microphone")
        }
        let granted = await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        let status = session.recordPermission
        if prompted, status == .undetermined {
            PermissionLogger.microphone(granted ? .granted : .denied, prompted: true)
        } else {
            PermissionLogger.microphone(status, prompted: prompted)
        }
        return granted
    }
}

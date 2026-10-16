//
//  ConnectionManager+Voice.swift
//  tvRemoteDemo
//

import Foundation

extension ConnectionManager {
    /// Runs what was said on the active TV: a key, a channel, an app, or words typed into the text box
    /// open on the TV followed by Enter. Throws a `TVError`: `unsupportedKey` for a key the TV lacks and
    /// `appUnavailable` when no app has that name. The words are never logged or stored.
    func perform(_ command: VoiceCommand) async throws {
        switch command {
        case .key(let key):
            try await send(key)
        case .channel(let number):
            try await openChannel(number)
        case .openApp(let name):
            let installed = try await apps()
            guard let app = VoiceCommandParser.match(appName: name, in: installed) else {
                throw TVError.appUnavailable
            }
            try await launch(app)
        case .text(let words):
            try await send(TextCommand.insert(words))
            try await send(TextCommand.enter)
        }
    }
}

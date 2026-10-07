//
//  TVError.swift
//  tvRemoteDemo
//

import Foundation

/// Why a command could not reach a TV.
nonisolated enum TVError: Error, Sendable, Equatable {
    /// The TV did not answer.
    case unreachable
    /// The TV answered too slowly.
    case timedOut
    /// The TV refused the command. On a Roku this means network control is switched off.
    case refused
    /// The TV answered but did not give this phone permission (Samsung, LG): the prompt on the TV was
    /// declined, or the TV's remote-control setting is off.
    case denied
    /// Nobody answered the Allow / Accept prompt on the TV in time (Samsung, LG).
    case awaitingApproval
    /// The TV closed the connection at once. On Android / Google TV that means this phone is not paired.
    case notPaired
    /// No TV is connected yet.
    case notConnected
    /// The TV has no equivalent of this key.
    case unsupportedKey(KeyCommand)
    /// This TV cannot take typed text from this app (yet).
    case unsupportedText
    /// The TV did not switch to that input (no such port).
    case inputFailed
    /// This TV has no way for this app to switch channels.
    case unsupportedChannels
    /// The TV did not switch to the channel (no such channel, or it has no tuner).
    case channelFailed
    /// This TV has no casting feature this app can use.
    case unsupportedCasting
    /// The TV could not start its player, or could not play the file (the format may not be supported).
    case castFailed
    /// This TV has no voice feature this app can use.
    case unsupportedVoice
    /// The TV did not start listening when asked (no assistant, not signed in, or voice is off).
    case voiceNotStarted
    /// This TV cannot list or open apps from this app (yet).
    case unsupportedApps
    /// The TV does not have the app, or refused to open it.
    case appUnavailable
    /// A character in the text cannot be typed on this TV. Nothing was sent.
    case unsupportedCharacter
    /// Control for this platform is not built yet.
    case unsupported(TVPlatform)
    /// The TV answered with something we cannot read.
    case badResponse
    /// This TV has no on-screen cursor this app can move.
    case unsupportedPointer
    /// No MAC address is saved for this TV, so it cannot be woken. Connecting to it once saves one.
    case wakeUnavailable
    /// The wake packet could not be sent (the network refused it, or this phone is not on Wi-Fi).
    case wakeFailed
    /// This phone could not create the certificate the TV wants (Android / Google TV).
    case identityUnavailable
}

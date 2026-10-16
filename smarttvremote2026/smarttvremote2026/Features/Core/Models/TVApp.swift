//
//  TVApp.swift
//  tvRemoteDemo
//

import Foundation

/// An app the launcher can open on a TV. `id` is whatever that TV's platform needs to open it: a
/// Roku or LG app id, a Samsung app id, or an Android / Google TV deep link.
nonisolated struct TVApp: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
}

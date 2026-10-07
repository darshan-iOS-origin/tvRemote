//
//  AndroidTVApps.swift
//  tvRemoteDemo
//
//  The Android / Google TV remote protocol has no list of installed apps, so the launcher shows
//  this fixed catalog and opens an app by sending its web address as a deep link: the TV hands the
//  link to the app that handles it.
//
//  The message is from AndroidTVRemoteControl's `DeepLink.swift` (MIT). Only Netflix's link is
//  confirmed by a source (that library's demo sends `https://www.netflix.com/title`). The others
//  are from memory and UNVERIFIED. TODO: confirm each on a real TV. An app that is not installed
//  does nothing, or the TV may show its store page.
//

import Foundation

nonisolated enum AndroidTVApps {
    static let catalog: [TVApp] = [
        TVApp(id: "https://www.netflix.com/title", name: "Netflix"),
        // UNVERIFIED from here on.
        TVApp(id: "https://www.youtube.com", name: "YouTube"),
        TVApp(id: "https://app.primevideo.com", name: "Prime Video"),
        TVApp(id: "https://www.disneyplus.com", name: "Disney+"),
        TVApp(id: "https://open.spotify.com", name: "Spotify")
    ]
}

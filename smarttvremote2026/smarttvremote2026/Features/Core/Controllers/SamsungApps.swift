//
//  SamsungApps.swift
//  tvRemoteDemo
//
//  No source we can read lists the apps installed on a Samsung TV, so the launcher shows this
//  fixed catalog. An app that is not installed answers 404, which is reported as not installed.
//
//  The ids and the launch call (`POST http://<ip>:8001/api/v2/applications/<id>`) are from
//  TVCommanderKit (https://github.com/wdesimini/TVCommanderKit, MIT, copyright 2023 Wilson
//  Desimini), `TVCommanderKit+Extensions.swift` and `TVAppManager.swift`. Only the ids are used, no
//  code is copied.
//

import Foundation

nonisolated enum SamsungApps {
    static let port: UInt16 = 8001

    static let catalog: [TVApp] = [
        TVApp(id: "3201907018807", name: "Netflix"),
        TVApp(id: "111299001912", name: "YouTube"),
        TVApp(id: "3201910019365", name: "Prime Video"),
        TVApp(id: "3201606009684", name: "Spotify"),
        TVApp(id: "3201601007625", name: "Hulu"),
        TVApp(id: "3202301029760", name: "Max"),
        TVApp(id: "3201710014981", name: "Paramount+"),
        TVApp(id: "3201808016802", name: "Pluto TV"),
        TVApp(id: "3201708014618", name: "ESPN")
    ]
}

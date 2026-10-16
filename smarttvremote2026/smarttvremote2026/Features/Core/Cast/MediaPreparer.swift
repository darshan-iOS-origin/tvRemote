//
//  MediaPreparer.swift
//  tvRemoteDemo
//
//  Turns what the user picked into a file a TV can play, in a temporary folder that is removed when
//  casting ends:
//  - photos become JPEG (a TV cannot show HEIC), turned the right way up and scaled down if huge;
//  - a .mov video is repackaged as .mp4 without re-encoding, which is quick; if that fails the
//    original is used as it is;
//  - music is copied with the right content type.
//  File names are never logged.
//
//  UNVERIFIED on a device: the photo and video conversions.
//

import AVFoundation
import ImageIO
import PhotosUI
import UniformTypeIdentifiers

nonisolated enum CastMediaKind: Sendable, Equatable {
    case photo
    case video
    case music
}

/// One file ready to cast.
nonisolated struct CastMedia: Sendable, Equatable, Identifiable {
    let id = UUID()
    var fileURL: URL
    var contentType: String
    var kind: CastMediaKind
    /// Shown on the TV's player. A generic name, never the file's own.
    var title: String
}

nonisolated enum CastMediaError: Error, Equatable {
    /// The phone has no Wi-Fi address to serve the file from.
    case noWiFi
    /// The web server could not start.
    case serverFailed
    /// The picked item could not be read or converted.
    case preparationFailed
}

nonisolated final class MediaPreparer: @unchecked Sendable {
    /// Photos wider or taller than this are scaled down: a TV shows no more, and a big file is slow.
    private static let maxPhotoPixels = 3840

    private let directory: URL

    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("cast-\(UUID().uuidString)", isDirectory: true)
    }

    /// Deletes every prepared file.
    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Photos and videos from the photo picker

    func prepare(_ result: PHPickerResult) async throws -> CastMedia {
        let provider = result.itemProvider
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            let copy = try await copyFile(from: provider, typeIdentifier: UTType.movie.identifier)
            return await video(from: copy)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let copy = try await copyFile(from: provider, typeIdentifier: UTType.image.identifier)
            return try photo(from: copy)
        }
        throw CastMediaError.preparationFailed
    }

    /// The picker's file only exists inside the callback, so it is copied there.
    private func copyFile(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL {
        try ensureDirectory()
        let folder = directory
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url, error == nil else {
                    continuation.resume(throwing: CastMediaError.preparationFailed)
                    return
                }
                let copy = folder.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(throwing: CastMediaError.preparationFailed)
                }
            }
        }
    }

    private func photo(from file: URL) throws -> CastMedia {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else {
            throw CastMediaError.preparationFailed
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPhotoPixels
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CastMediaError.preparationFailed
        }
        let output = directory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CastMediaError.preparationFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CastMediaError.preparationFailed
        }
        try? FileManager.default.removeItem(at: file)
        return CastMedia(fileURL: output, contentType: "image/jpeg", kind: .photo, title: "Photo")
    }

    private func video(from file: URL) async -> CastMedia {
        let fallback = CastMedia(fileURL: file, contentType: Self.contentType(forExtension: file.pathExtension, fallback: "video/mp4"), kind: .video, title: "Video")
        guard file.pathExtension.lowercased() == "mov" else {
            return fallback
        }
        // Repackage, do not re-encode. If the codec does not fit an mp4, keep the original.
        let output = directory.appendingPathComponent(UUID().uuidString + ".mp4")
        let asset = AVURLAsset(url: file)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            return fallback
        }
        export.outputURL = output
        export.outputFileType = .mp4
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously {
                continuation.resume()
            }
        }
        guard export.status == .completed else {
            try? FileManager.default.removeItem(at: output)
            return fallback
        }
        try? FileManager.default.removeItem(at: file)
        return CastMedia(fileURL: output, contentType: "video/mp4", kind: .video, title: "Video")
    }

    // MARK: - Music from the Files picker

    /// `url` is a copy the document picker made (it is opened with `asCopy`), so no security scope is needed.
    func prepareMusic(at url: URL) throws -> CastMedia {
        try ensureDirectory()
        let copy = directory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: copy)
        } catch {
            throw CastMediaError.preparationFailed
        }
        return CastMedia(
            fileURL: copy,
            contentType: Self.contentType(forExtension: url.pathExtension, fallback: "audio/mpeg"),
            kind: .music,
            title: "Music"
        )
    }

    // MARK: - Helpers

    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CastMediaError.preparationFailed
        }
    }

    private static func contentType(forExtension ext: String, fallback: String) -> String {
        switch ext.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "aac": return "audio/aac"
        case "wav": return "audio/wav"
        case "flac": return "audio/flac"
        case "ogg", "oga": return "audio/ogg"
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        default: return UTType(filenameExtension: ext)?.preferredMIMEType ?? fallback
        }
    }
}

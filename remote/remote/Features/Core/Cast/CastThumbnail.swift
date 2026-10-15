//
//  CastThumbnail.swift
//  tvRemoteDemo
//
//  A small picture of the item being cast, for the preview on the Cast screen: a photo is scaled down,
//  a video gives a frame from near its start. Music has none. Made from the prepared file on the phone;
//  nothing is sent anywhere and file names are never logged.
//

import AVFoundation
import ImageIO

nonisolated enum CastThumbnail {
    /// Longest side of the picture, in pixels.
    private static let maxPixels = 640

    /// The picture for `media`, or nil for music or a file that cannot be read.
    static func make(for media: CastMedia) async -> CGImage? {
        switch media.kind {
        case .photo:
            return photo(at: media.fileURL)
        case .video:
            return await videoFrame(at: media.fileURL)
        case .music:
            return nil
        }
    }

    private static func photo(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func videoFrame(at url: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
        // A frame a moment in is rarely black; a very short clip falls back to the first frame.
        for seconds in [1.0, 0.0] {
            if let image = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image {
                return image
            }
        }
        return nil
    }
}

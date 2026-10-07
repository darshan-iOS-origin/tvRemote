import UIKit
import Foundation
import Network
import StoreKit

// MARK: - External URLs & system sheets

enum AppExternalLinks {
    static let terms = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let privacy = "https://sites.google.com/view/authenticatorsecure/home"
    static let appURL = "https://apps.apple.com/app/id6804940631"
}

func openURLInSafari(_ urlString: String) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let normalizedURLString: String
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
        normalizedURLString = trimmed
    } else {
        normalizedURLString = "https://\(trimmed)"
    }

    guard let url = URL(string: normalizedURLString),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
}

func openURLInSafari(_ url: URL) {
    openURLInSafari(url.absoluteString)
}

func requestDefaultAppStoreReview() {
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
        ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return }
    SKStoreReviewController.requestReview(in: scene)
}

func presentSystemShareSheet(from viewController: UIViewController, items: [Any], sourceView: UIView? = nil) {
    guard !items.isEmpty else { return }
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
        let anchor = sourceView ?? viewController.view
        popover.sourceView = anchor
        popover.sourceRect = anchor?.bounds ?? .zero
        popover.permittedArrowDirections = []
    }
    viewController.present(activity, animated: true)
}

func isSmallDevice() -> Bool {
    return UIScreen.main.bounds.height == 667
}

func isIpad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func isLandscapeImage(_ image: UIImage) -> Bool {
    let width = image.size.width * image.scale
    let height = image.size.height * image.scale
    
    switch image.imageOrientation {
    case .left, .right, .leftMirrored, .rightMirrored:
        return height > width
    default:
        return width > height
    }
}

func makeThumbnailForCell(from image: UIImage, maxDimension: CGFloat, displayScale: CGFloat) -> UIImage {
    let size = image.size
    let maxSide = max(size.width, size.height)
    guard maxSide > maxDimension else { return image }
    let scale = maxDimension / maxSide
    let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = displayScale
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { ctx in
        ctx.cgContext.interpolationQuality = .high
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

func isInternetAvailable() -> Bool {
    let monitor = NWPathMonitor()
    let semaphore = DispatchSemaphore(value: 0)
    var isConnected = false
    
    monitor.pathUpdateHandler = { path in
        isConnected = path.status == .satisfied
        semaphore.signal()
    }
    
    let queue = DispatchQueue(label: "NetworkMonitor")
    monitor.start(queue: queue)
    
    semaphore.wait()
    monitor.cancel()
    
    return isConnected
}

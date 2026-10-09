#if DEBUG
import CoreMedia
import CoreVideo
import Security
import UIKit

/// Debug builds only. The iOS Simulator can't run the broadcast extension, so this stands in for it: it
/// draws a moving test picture and runs the same encoder (`HLSLiveSegmenter`) and web server
/// (`MirrorStreamServer`) inside the app. Everything after the screen capture — the stream, the server,
/// Google Cast and the TV's player — can then be tested in the Simulator with the Android TV emulator,
/// or by opening the stream's address in Safari or VLC on the Mac.
///
/// The picture shows a clock and a frame counter, so a frozen or late picture on the TV is easy to see.
nonisolated final class MirrorTestStream: @unchecked Sendable {
    private static let framesPerSecond = 15.0
    /// The same rule as the extension: the TV's player wants a few segments to start from.
    private static let segmentsBeforeReady = 3

    let token: String

    private let segmenter = HLSLiveSegmenter()
    private let server = MirrorStreamServer(wifiOnly: false, allowLoopback: true)
    private let queue = DispatchQueue(label: "mirror.test.frames")
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var frameNumber = 0
    private var port: UInt16 = 0
    private var segmentCount = 0
    private var reported = false
    private var onReady: (@Sendable (UInt16) -> Void)?
    private var onFailure: (@Sendable () -> Void)?

    init() {
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        }
        token = bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Starts drawing and serving. `onReady` gets the port once the stream can be played; `onFailure` is
    /// called if the encoder or the server stops. Both are called once at most, on a background queue.
    func start(onReady: @escaping @Sendable (UInt16) -> Void, onFailure: @escaping @Sendable () -> Void) {
        lock.lock()
        self.onReady = onReady
        self.onFailure = onFailure
        lock.unlock()

        segmenter.onSegment = { [weak self] count in
            guard let self else { return }
            self.lock.lock()
            self.segmentCount = count
            self.lock.unlock()
            self.reportIfReady()
        }
        segmenter.onFailure = { [weak self] in
            DispatchQueue.global().async { self?.failed() }
        }
        segmenter.start()

        server.start(token: token, segmenter: segmenter) { [weak self] port in
            guard let self else { return }
            guard let port else {
                self.failed()
                return
            }
            self.lock.lock()
            self.port = port
            self.lock.unlock()
            self.reportIfReady()
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / Self.framesPerSecond)
        timer.setEventHandler { [weak self] in self?.drawFrame() }
        timer.resume()
        lock.lock()
        self.timer = timer
        lock.unlock()
    }

    func stop() {
        lock.lock()
        let timer = self.timer
        self.timer = nil
        onReady = nil
        onFailure = nil
        lock.unlock()
        timer?.cancel()
        server.stop()
        segmenter.stop()
    }

    // MARK: - Private

    private func reportIfReady() {
        lock.lock()
        let ready = !reported && port != 0 && segmentCount >= Self.segmentsBeforeReady
        if ready { reported = true }
        let port = self.port
        let callback = ready ? onReady : nil
        lock.unlock()
        callback?(port)
    }

    private func failed() {
        lock.lock()
        let callback = onFailure
        onFailure = nil
        onReady = nil
        lock.unlock()
        callback?()
    }

    private func drawFrame() {
        frameNumber += 1
        guard let buffer = Self.makeFrame(number: frameNumber) else { return }
        segmenter.appendPixelBuffer(buffer, orientation: .up, at: CMClockGetTime(CMClockGetHostTimeClock()))
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.S"
        return formatter
    }()

    /// A 1280×720 picture: a slowly changing background, a bar that sweeps across once a second, the time
    /// and the frame number.
    private static func makeFrame(number: Int) -> CVPixelBuffer? {
        let width = HLSLiveSegmenter.width
        let height = HLSLiveSegmenter.height
        var output: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ]
        guard CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &output
        ) == kCVReturnSuccess, let output else { return nil }

        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(output),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(output),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // UIKit drawing (text) expects a top-left origin.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let hue = CGFloat(number % 600) / 600
        UIColor(hue: hue, saturation: 0.55, brightness: 0.35, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let progress = CGFloat(number % Int(framesPerSecond)) / CGFloat(framesPerSecond)
        UIColor.white.setFill()
        context.fill(CGRect(x: progress * CGFloat(width - 80), y: CGFloat(height) - 120, width: 80, height: 40))

        let title = "TV Control — mirroring test"
        let clock = clockFormatter.string(from: Date())
        let detail = "frame \(number)"
        draw(title, size: 44, weight: .bold, y: 160, width: width)
        draw(clock, size: 96, weight: .heavy, y: 260, width: width)
        draw(detail, size: 36, weight: .medium, y: 420, width: width)
        return output
    }

    private static func draw(_ text: String, size: CGFloat, weight: UIFont.Weight, y: CGFloat, width: Int) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: CGRect(x: 0, y: y, width: CGFloat(width), height: size * 1.4), withAttributes: attributes)
    }
}
#endif

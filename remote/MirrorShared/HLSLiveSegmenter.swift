//
//  HLSLiveSegmenter.swift
//  MirrorBroadcast (and the app's DEBUG Simulator test stream, `MirrorTestStream`)
//
//  Turns ReplayKit's screen frames and app audio into a live HLS stream in memory: H.264 video and AAC
//  audio in fragmented MP4 segments of about one second, plus the playlist that lists the newest ones.
//  Apple's own `AVAssetWriter` cuts the segments (`.mpeg4AppleHLS`), so there is no muxer of our own.
//
//  Every frame is drawn upright and fitted into a 1280×720 picture, so a portrait screen shows with black
//  bars and a landscape app fills the TV. ReplayKit sends no frames while the screen is still and no audio
//  while nothing plays, but the segmenter needs both to move on, so a timer repeats the last frame and
//  adds silence.
//
//  Threading: everything that touches the writer runs on `queue`. The finished segments are read by the
//  web server from its own queue, under `lock`.
//
//  UNVERIFIED on a device: the orientation attachment's direction, the 50 MB memory limit with these
//  settings, and that a Google Cast receiver plays this fMP4 stream.
//

import AVFoundation
import CoreImage
import os
import ReplayKit
import UniformTypeIdentifiers

nonisolated final class HLSLiveSegmenter: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
    struct Segment {
        let sequence: Int
        let duration: Double
        let data: Data
    }

    static let width = 1280
    static let height = 720
    private static let framesPerSecond: Int32 = 30
    private static let videoBitRate = 3_500_000
    private static let segmentSeconds: Double = 1
    /// Segments kept in memory and listed in the playlist. Six one-second segments are about 3 MB.
    private static let keptSegments = 6
    /// A frame is repeated when no new one came for this long.
    private static let repeatFrameAfter: Double = 0.2
    /// Silence is added when no audio came for this long.
    private static let silenceAfter: Double = 0.3

    private static let audioSampleRate: Double = 44_100
    private static let audioChannels: AVAudioChannelCount = 2

    /// Called on the segmenter's queue each time a segment is ready, with how many have been made so far.
    var onSegment: ((Int) -> Void)?
    /// Called on the segmenter's queue when the writer stops working.
    var onFailure: (() -> Void)?

    private let log = Logger(subsystem: MirrorShared.extensionBundleID, category: "Segmenter")
    private let queue = DispatchQueue(label: "mirror.segmenter")
    private let lock = NSLock()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let background = CIImage(color: .black).cropped(
        to: CGRect(x: 0, y: 0, width: HLSLiveSegmenter.width, height: HLSLiveSegmenter.height)
    )

    // Writer state, on `queue`.
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var timer: DispatchSourceTimer?
    private var isStopped = false
    private var failed = false
    private var lastVideoTime = CMTime.invalid
    private var lastFrame: CVPixelBuffer?
    private var audioEnd = CMTime.invalid
    private var audioFormat: CMAudioFormatDescription?
    private var outputAudioFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var converterSource: AVAudioFormat?
    private var lastHeartbeat = Date.distantPast

    // Finished output, under `lock`.
    private var initSegment: Data?
    private var segments: [Segment] = []
    private var madeSegments = 0

    // MARK: - Lifecycle

    func start() {
        queue.async { [self] in
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
            timer.setEventHandler { [weak self] in self?.tick() }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.sync {
            isStopped = true
            timer?.cancel()
            timer = nil
            if let writer, writer.status == .writing {
                writer.cancelWriting()
            }
            writer = nil
            videoInput = nil
            audioInput = nil
            adaptor = nil
            lastFrame = nil
        }
        lock.lock()
        initSegment = nil
        segments = []
        lock.unlock()
    }

    // MARK: - Input

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        appendPixelBuffer(
            source,
            orientation: Self.orientation(of: sampleBuffer),
            at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        )
    }

    /// One screen picture, stamped with the host clock. ReplayKit's frames come through `appendVideo`; the
    /// DEBUG Simulator test stream calls this directly.
    func appendPixelBuffer(_ source: CVPixelBuffer, orientation: CGImagePropertyOrientation, at time: CMTime) {
        // Synchronous: ReplayKit reuses its buffers, so the frame is drawn into our own before returning.
        queue.sync {
            guard !isStopped, !failed, time.isValid else { return }
            if writer == nil {
                startWriter(at: time)
            }
            // At most 30 frames a second: the TV gains nothing from more, and the extension has little memory.
            if lastVideoTime.isValid, (time - lastVideoTime).seconds < 1.0 / Double(Self.framesPerSecond) * 0.9 {
                return
            }
            guard let frame = render(source, orientation: orientation) else { return }
            lastFrame = frame
            appendFrame(frame, at: time)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        queue.sync {
            guard !isStopped, !failed, writer != nil, let converted = convertAudio(sampleBuffer) else { return }
            appendAudioBuffer(converted)
        }
    }

    // MARK: - Reading (web server)

    func playlist() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard initSegment != nil, let first = segments.first else { return nil }
        let target = max(2, Int(ceil(segments.map(\.duration).max() ?? Self.segmentSeconds)))
        var text = "#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:\(target)\n"
        text += "#EXT-X-MEDIA-SEQUENCE:\(first.sequence)\n#EXT-X-INDEPENDENT-SEGMENTS\n"
        text += "#EXT-X-MAP:URI=\"\(MirrorShared.initSegmentName)\"\n"
        for segment in segments {
            text += String(format: "#EXTINF:%.3f,\n", segment.duration)
            text += "seg\(segment.sequence).m4s\n"
        }
        return Data(text.utf8)
    }

    func initializationData() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return initSegment
    }

    func segment(sequence: Int) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return segments.first { $0.sequence == sequence }?.data
    }

    // MARK: - Writer

    private func startWriter(at time: CMTime) {
        let writer = AVAssetWriter(contentType: .mpeg4Movie)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = CMTime(seconds: Self.segmentSeconds, preferredTimescale: 1000)
        writer.initialSegmentStartTime = time
        writer.delegate = self

        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: Self.videoBitRate,
            AVVideoExpectedSourceFrameRateKey: Self.framesPerSecond,
            AVVideoMaxKeyFrameIntervalKey: Self.framesPerSecond,
            AVVideoMaxKeyFrameIntervalDurationKey: Self.segmentSeconds,
            AVVideoAllowFrameReorderingKey: false,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Self.width,
            AVVideoHeightKey: Self.height,
            AVVideoCompressionPropertiesKey: compression
        ])
        video.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Self.width,
            kCVPixelBufferHeightKey as String: Self.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ])

        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Self.audioSampleRate,
            AVNumberOfChannelsKey: Int(Self.audioChannels),
            AVEncoderBitRateKey: 128_000
        ])
        audio.expectsMediaDataInRealTime = true

        guard writer.canAdd(video), writer.canAdd(audio) else {
            fail("the writer refused an input")
            return
        }
        writer.add(video)
        writer.add(audio)
        guard writer.startWriting() else {
            fail("startWriting: \(String(describing: writer.error))")
            return
        }
        writer.startSession(atSourceTime: time)

        self.writer = writer
        videoInput = video
        audioInput = audio
        self.adaptor = adaptor
        // The audio track starts with silence until the first real audio comes.
        audioEnd = time
        log.info("Writer started")
    }

    private func appendFrame(_ frame: CVPixelBuffer, at time: CMTime) {
        guard let writer, writer.status == .writing, let videoInput, let adaptor else {
            checkFailure()
            return
        }
        guard videoInput.isReadyForMoreMediaData else { return }
        if adaptor.append(frame, withPresentationTime: time) {
            lastVideoTime = time
        } else {
            checkFailure()
        }
    }

    private func appendAudioBuffer(_ buffer: CMSampleBuffer) {
        guard let writer, writer.status == .writing, let audioInput else {
            checkFailure()
            return
        }
        guard audioInput.isReadyForMoreMediaData else { return }
        var buffer = buffer
        let start = CMSampleBufferGetPresentationTimeStamp(buffer)
        // Real audio that overlaps silence we already added is moved to just after it.
        if audioEnd.isValid, start < audioEnd, let moved = Self.retimed(buffer, to: audioEnd) {
            buffer = moved
        }
        if audioInput.append(buffer) {
            let newStart = CMSampleBufferGetPresentationTimeStamp(buffer)
            audioEnd = newStart + CMSampleBufferGetDuration(buffer)
        } else {
            checkFailure()
        }
    }

    private func checkFailure() {
        if let writer, writer.status == .failed {
            fail("writer failed: \(String(describing: writer.error))")
        }
    }

    private func fail(_ reason: String) {
        guard !failed else { return }
        failed = true
        log.error("Segmenter stopped: \(reason, privacy: .public)")
        onFailure?()
    }

    // MARK: - Timer: repeated frames, silence, heartbeat

    private func tick() {
        guard !isStopped, !failed, writer != nil else { return }
        // ReplayKit stamps its samples with the host clock, so "now" is on the same timeline.
        // UNVERIFIED on a device.
        let now = CMClockGetTime(CMClockGetHostTimeClock())

        if let lastFrame, lastVideoTime.isValid, (now - lastVideoTime).seconds > Self.repeatFrameAfter {
            appendFrame(lastFrame, at: now)
        }

        if audioEnd.isValid, (now - audioEnd).seconds > Self.silenceAfter {
            // Fill up to a little before now, so real audio that is on its way still fits after it.
            let until = now - CMTime(seconds: 0.1, preferredTimescale: 1000)
            let frames = Int((until - audioEnd).seconds * Self.audioSampleRate)
            if frames > 0, let silence = makeSilence(at: audioEnd, frames: frames) {
                appendAudioBuffer(silence)
            }
        }

        if Date().timeIntervalSince(lastHeartbeat) >= MirrorShared.heartbeatInterval {
            lastHeartbeat = Date()
            MirrorShared.touch()
        }
    }

    // MARK: - AVAssetWriterDelegate

    func assetWriter(
        _ writer: AVAssetWriter,
        didOutputSegmentData segmentData: Data,
        segmentType: AVAssetSegmentType,
        segmentReport: AVAssetSegmentReport?
    ) {
        lock.lock()
        let count: Int
        switch segmentType {
        case .initialization:
            initSegment = segmentData
            lock.unlock()
            return
        case .separable:
            let video = segmentReport?.trackReports.first { $0.mediaType == .video }
            let seconds = video.map { $0.duration.seconds } ?? Self.segmentSeconds
            let duration = seconds.isFinite && seconds > 0 ? seconds : Self.segmentSeconds
            segments.append(Segment(sequence: madeSegments, duration: duration, data: segmentData))
            madeSegments += 1
            if segments.count > Self.keptSegments {
                segments.removeFirst(segments.count - Self.keptSegments)
            }
            count = madeSegments
        @unknown default:
            lock.unlock()
            return
        }
        lock.unlock()
        queue.async { [weak self] in self?.onSegment?(count) }
    }

    // MARK: - Video

    private static func orientation(of sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        guard let number = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
              let orientation = CGImagePropertyOrientation(rawValue: number.uint32Value) else {
            return .up
        }
        return orientation
    }

    /// Draws the screen upright, fitted and centered on a black 1280×720 picture.
    private func render(_ source: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        guard let pool = adaptor?.pixelBufferPool else { return nil }
        var output: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &output) == kCVReturnSuccess, let output else {
            return nil
        }
        var image = CIImage(cvPixelBuffer: source).oriented(orientation)
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scale = min(CGFloat(Self.width) / extent.width, CGFloat(Self.height) / extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let fitted = image.extent
        image = image.transformed(by: CGAffineTransform(
            translationX: (CGFloat(Self.width) - fitted.width) / 2 - fitted.minX,
            y: (CGFloat(Self.height) - fitted.height) / 2 - fitted.minY
        ))
        ciContext.render(
            image.composited(over: background),
            to: output,
            bounds: CGRect(x: 0, y: 0, width: Self.width, height: Self.height),
            colorSpace: colorSpace
        )
        return output
    }

    // MARK: - Audio

    /// ReplayKit's audio format can change from app to app, and one writer input should get one format, so
    /// every buffer is converted to 44.1 kHz stereo 16-bit before it is added.
    private func convertAudio(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              let sourceFormat = AVAudioFormat(streamDescription: streamDescription),
              let outputFormat = outputAudioFormatValue() else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames) else { return nil }
        input.frameLength = frames
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: input.mutableAudioBufferList
        ) == noErr else { return nil }

        if converter == nil || converterSource != sourceFormat {
            converter = AVAudioConverter(from: sourceFormat, to: outputFormat)
            converterSource = sourceFormat
        }
        guard let converter else { return nil }
        let capacity = AVAudioFrameCount(Double(frames) * outputFormat.sampleRate / sourceFormat.sampleRate) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }
        var given = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if given {
                inputStatus.pointee = .noDataNow
                return nil
            }
            given = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return makeAudioSample(from: output, at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }

    private func outputAudioFormatValue() -> AVAudioFormat? {
        if outputAudioFormat == nil {
            outputAudioFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Self.audioSampleRate,
                channels: Self.audioChannels,
                interleaved: true
            )
        }
        return outputAudioFormat
    }

    private func outputAudioDescription() -> CMAudioFormatDescription? {
        if audioFormat == nil, let format = outputAudioFormatValue() {
            var description: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: format.streamDescription,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &description
            )
            audioFormat = description
        }
        return audioFormat
    }

    private func makeAudioSample(from buffer: AVAudioPCMBuffer, at time: CMTime) -> CMSampleBuffer? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let data = audioBuffer.mData else { return nil }
        return makeAudioSample(bytes: data, length: Int(audioBuffer.mDataByteSize), frames: Int(buffer.frameLength), at: time)
    }

    private func makeSilence(at time: CMTime, frames: Int) -> CMSampleBuffer? {
        let bytesPerFrame = Int(Self.audioChannels) * MemoryLayout<Int16>.size
        let zeros = [UInt8](repeating: 0, count: frames * bytesPerFrame)
        return zeros.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return nil }
            return makeAudioSample(bytes: UnsafeMutableRawPointer(mutating: base), length: raw.count, frames: frames, at: time)
        }
    }

    /// A sample buffer that owns a copy of `bytes`, in the output audio format.
    private func makeAudioSample(bytes: UnsafeMutableRawPointer, length: Int, frames: Int, at time: CMTime) -> CMSampleBuffer? {
        guard length > 0, frames > 0, let format = outputAudioDescription() else { return nil }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: length,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: length,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block
        ) == kCMBlockBufferNoErr, let block else { return nil }
        guard CMBlockBufferReplaceDataBytes(with: bytes, blockBuffer: block, offsetIntoDestination: 0, dataLength: length)
            == kCMBlockBufferNoErr else { return nil }
        var sample: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            formatDescription: format,
            sampleCount: frames,
            presentationTimeStamp: time,
            packetDescriptions: nil,
            sampleBufferOut: &sample
        ) == noErr else { return nil }
        return sample
    }

    /// The same audio with a new start time.
    private static func retimed(_ buffer: CMSampleBuffer, to time: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(audioSampleRate)),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        var copy: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: buffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &copy
        ) == noErr else { return nil }
        return copy
    }
}

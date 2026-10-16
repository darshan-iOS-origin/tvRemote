//
//  MotionPointer.swift
//  tvRemoteDemo
//
//  Turns the way the phone is waved into cursor movement, like pointing a Magic Remote. It uses Apple's
//  Core Motion device motion at 60 Hz: the rotation rate about the vertical axis moves the cursor
//  left and right, and the rotation about the phone's own side-to-side axis moves it up and down.
//  Nothing is stored or sent but the movement numbers.
//
//  UNVERIFIED on a device: the feel, and the signs of the axes. Both are tunable in the constants
//  below. The iOS Simulator has no motion sensors (`isAvailable` is false there).
//

import CoreMotion
import Foundation

nonisolated final class MotionPointer: @unchecked Sendable {
    /// Cursor points per radian of turn. Larger is faster.
    static let pointsPerRadian = 900.0
    /// Turns slower than this, in radians per second, are ignored, so a resting hand does not drift.
    static let deadZone = 0.04
    private static let interval = 1.0 / 60.0

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private var carryX = 0.0
    private var carryY = 0.0

    /// Called on the main queue with whole points to move, right and down being positive.
    var onMove: (@Sendable (Int, Int) -> Void)?

    init() {
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        carryX = 0
        carryY = 0
        manager.deviceMotionUpdateInterval = Self.interval
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            self?.handle(
                rate: (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z),
                gravity: (motion.gravity.x, motion.gravity.y, motion.gravity.z)
            )
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func handle(rate: (Double, Double, Double), gravity: (Double, Double, Double)) {
        let step = Self.delta(rate: rate, gravity: gravity, seconds: Self.interval)
        carryX += step.dx
        carryY += step.dy
        let wholeX = Int(carryX)
        let wholeY = Int(carryY)
        guard wholeX != 0 || wholeY != 0 else { return }
        carryX -= Double(wholeX)
        carryY -= Double(wholeY)
        let onMove = self.onMove
        DispatchQueue.main.async { onMove?(wholeX, wholeY) }
    }

    /// The cursor movement for one tick, in points. Public for checking: this is the arithmetic.
    /// - Horizontal: the turn about the vertical axis is `rate · gravity` (CoreMotion's gravity points
    ///   down), so it works whether the phone is upright or flat. A turn to the right is positive.
    /// - Vertical: the turn about the phone's x axis (side to side). Nose up is positive, and the cursor
    ///   goes up, so the sign is flipped.
    static func delta(
        rate: (x: Double, y: Double, z: Double),
        gravity: (x: Double, y: Double, z: Double),
        seconds: Double
    ) -> (dx: Double, dy: Double) {
        var yaw = rate.x * gravity.x + rate.y * gravity.y + rate.z * gravity.z
        var pitch = rate.x
        if abs(yaw) < deadZone { yaw = 0 }
        if abs(pitch) < deadZone { pitch = 0 }
        return (yaw * seconds * pointsPerRadian, -pitch * seconds * pointsPerRadian)
    }
}

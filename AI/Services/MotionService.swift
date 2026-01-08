//
//  MotionService.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//
import Foundation
import CoreMotion

final class MotionService {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private var onSample: ((MotionSample) -> Void)?
    private(set) var isStreaming = false

    func startStreaming(updateHz: Double = 50.0, onSample: @escaping (MotionSample) -> Void) {
        guard !isStreaming else { return }
        isStreaming = true
        self.onSample = onSample

        guard manager.isDeviceMotionAvailable else {
            print("DeviceMotion not available.")
            return
        }

        manager.deviceMotionUpdateInterval = 1.0 / max(1.0, updateHz)

        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                print("DeviceMotion error:", error)
                return
            }
            guard let motion else { return }

            let sample = MotionSample(
                timestamp: motion.timestamp,
                userAcceleration: .init(x: motion.userAcceleration.x,
                                        y: motion.userAcceleration.y,
                                        z: motion.userAcceleration.z),
                rotationRate: .init(x: motion.rotationRate.x,
                                    y: motion.rotationRate.y,
                                    z: motion.rotationRate.z),
                gravity: .init(x: motion.gravity.x,
                               y: motion.gravity.y,
                               z: motion.gravity.z)
            )
            DispatchQueue.main.async {
                self.onSample?(sample)
            }
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }
        isStreaming = false
        manager.stopDeviceMotionUpdates()
        onSample = nil
    }
}

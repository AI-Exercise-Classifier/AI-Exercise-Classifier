//
//  WatchLiveWorkoutViewModel.swift
//  AI (watch target)
//

import Foundation
import CoreMotion
import Combine

@MainActor
final class WatchLiveWorkoutViewModel: ObservableObject {

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentHz: Double = 0

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    private var batcher: MotionBatcher?
    private let keeper = WatchWorkoutKeeper()
    private var cancellables = Set<AnyCancellable>()

    init() {
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1

        // Se till att WCSession-delegaten lever tidigt
        _ = WatchCommandReceiver.shared

        // Start från iPhone
        NotificationCenter.default.publisher(for: .watchCommandStart)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self else { return }
                let hz = (note.userInfo?["hz"] as? Double) ?? 100.0
                self.startIfNeeded(hz: hz)
            }
            .store(in: &cancellables)

        // Stop från iPhone
        NotificationCenter.default.publisher(for: .watchCommandStop)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.stopIfNeeded()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public (om du vill trigga manuellt från UI)
    func start(hz: Double) { startIfNeeded(hz: hz) }
    func stop() { stopIfNeeded() }

    // MARK: - Idempotent start/stop
    func startIfNeeded(hz: Double) {
        guard !isRunning else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ DeviceMotion not available")
            return
        }

        isRunning = true
        currentHz = hz

        keeper.startIfNeeded()
        _ = WatchCommandReceiver.shared

        batcher = MotionBatcher(hz: hz, batchSize: 10)

        motionManager.deviceMotionUpdateInterval = 1.0 / hz
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            if let error {
                print("❌ motion error:", error)
                return
            }
            guard let self,
                  let m = motion,
                  self.isRunning else { return }

            let sample = MotionSample(
                timestamp: m.timestamp,
                userAcceleration: .init(x: m.userAcceleration.x, y: m.userAcceleration.y, z: m.userAcceleration.z),
                rotationRate: .init(x: m.rotationRate.x, y: m.rotationRate.y, z: m.rotationRate.z),
                gravity: .init(x: m.gravity.x, y: m.gravity.y, z: m.gravity.z)
            )

            Task { @MainActor in
                self.batcher?.append(sample)
            }
        }

        print("✅ Watch LIVE stream started @ \(hz) Hz")
    }

    func stopIfNeeded() {
        guard isRunning else { return }
        isRunning = false
        currentHz = 0

        motionManager.stopDeviceMotionUpdates()
        batcher?.flush()
        batcher = nil

        keeper.stopIfNeeded()
        print("🛑 Watch LIVE stream stopped")
    }
}

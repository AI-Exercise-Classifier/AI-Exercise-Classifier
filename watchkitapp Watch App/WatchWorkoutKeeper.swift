import Foundation
import HealthKit
import Combine
final class WatchWorkoutKeeper: NSObject, HKWorkoutSessionDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?

    func startIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if session != nil { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            s.delegate = self
            session = s
            s.startActivity(with: Date())
            print("✅ HKWorkoutSession started (keeps alive)")
        } catch {
            print("❌ HKWorkoutSession start error:", error)
        }
    }

    func stopIfNeeded() {
        guard let s = session else { return }
        s.end()
        session = nil
        print("🛑 HKWorkoutSession stopped")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ HKWorkoutSession failed:", error)
    }
}

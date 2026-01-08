import Foundation

/// Detects ACTIVE vs REST from a smoothed 1D motion signal (e.g., accMagLP).
/// Uses hysteresis thresholds + minimum dwell time.
final class ActivityDetector {

    enum State: String {
        case resting
        case active
    }

    struct Config {
        var enterActiveThreshold: Double = 0.06
        var exitActiveThreshold: Double = 0.04
        var minActiveDuration: TimeInterval = 0.35
        var minRestDuration: TimeInterval = 0.9
    }

    private(set) var state: State = .resting
    private var config: Config

    // Candidate timing
    private var aboveSince: TimeInterval?
    private var belowSince: TimeInterval?

    init(config: Config = Config()) {
        self.config = config
    }

    func updateConfig(_ newConfig: Config) {
        self.config = newConfig
    }

    func reset() {
        state = .resting
        aboveSince = nil
        belowSince = nil
    }

    /// Update with latest motion magnitude.
    func update(timestamp: TimeInterval, motionValue: Double) -> State {

        switch state {

        case .resting:
            if motionValue >= config.enterActiveThreshold {
                if aboveSince == nil {
                    aboveSince = timestamp
                }

                if let t0 = aboveSince,
                   (timestamp - t0) >= config.minActiveDuration {
                    state = .active
                    belowSince = nil
                }
            } else {
                aboveSince = nil
            }

        case .active:
            if motionValue <= config.exitActiveThreshold {
                if belowSince == nil {
                    belowSince = timestamp
                }

                if let t0 = belowSince,
                   (timestamp - t0) >= config.minRestDuration {
                    state = .resting
                    aboveSince = nil
                }
            } else {
                belowSince = nil
            }
        }

        return state
    }
}

import Foundation

final class RepDetector {

    struct RepEvent {
        let timestamp: TimeInterval
        let peakValue: Double
        let baselineValue: Double
        let prominence: Double
        let repInterval: TimeInterval?
    }

    struct Config {
        var minRepInterval: TimeInterval
        var fallDelta: Double
        var minProminence: Double
        var baselineTau: TimeInterval
        var maxRepInterval: TimeInterval
        var minGyroMagnitude: Double

        /// ✅ NEW: after counting a rep, signal must drop by at least this much
        /// before we allow the next rep. (prevents up+down double count)
        var rearmDrop: Double

        init(minRepInterval: TimeInterval = 0.80,
             fallDelta: Double = 0.080,
             minProminence: Double = 0.090,
             baselineTau: TimeInterval = 3.0,
             maxRepInterval: TimeInterval = 6.0,
             minGyroMagnitude: Double = 0.6,
             rearmDrop: Double = 0.85) {
            self.minRepInterval = minRepInterval
            self.fallDelta = fallDelta
            self.minProminence = minProminence
            self.baselineTau = baselineTau
            self.maxRepInterval = maxRepInterval
            self.minGyroMagnitude = minGyroMagnitude
            self.rearmDrop = rearmDrop
        }
    }

    private(set) var config: Config

    private var baseline: Double = 0
    private var baselineInitialized = false
    private var lastTimestamp: TimeInterval?

    private var candidatePeakValue: Double = -Double.greatestFiniteMagnitude
    private var candidatePeakTime: TimeInterval = 0
    private var peakGyroMagnitude: Double = 0

    private var lastRepTime: TimeInterval?

    // ✅ NEW: re-arm gate
    private var isArmedForNextRep: Bool = true
    private var lastCountedPeakValue: Double = 0

    init(config: Config = Config()) {
        self.config = config
    }

    func updateConfig(_ newConfig: Config) {
        self.config = newConfig
    }

    func reset() {
        baseline = 0
        baselineInitialized = false
        lastTimestamp = nil

        candidatePeakValue = -Double.greatestFiniteMagnitude
        candidatePeakTime = 0
        peakGyroMagnitude = 0

        lastRepTime = nil

        isArmedForNextRep = true
        lastCountedPeakValue = 0
    }

    func update(timestamp: TimeInterval,
                value: Double,
                gyroMagLP: Double,
                shouldCountReps: Bool) -> RepEvent? {

        updateBaseline(timestamp: timestamp, value: value)

        guard shouldCountReps else {
            candidatePeakValue = -Double.greatestFiniteMagnitude
            candidatePeakTime = timestamp
            peakGyroMagnitude = 0
            isArmedForNextRep = true
            return nil
        }

        // ✅ If we just counted a rep, wait until the signal drops enough (rearm)
        if !isArmedForNextRep {
            // require a real drop from last counted peak
            if value <= (lastCountedPeakValue - config.rearmDrop) {
                isArmedForNextRep = true
                // reset peak search from here
                candidatePeakValue = value
                candidatePeakTime = timestamp
                peakGyroMagnitude = gyroMagLP
            }
            return nil
        }

        peakGyroMagnitude = max(peakGyroMagnitude, gyroMagLP)

        // track peak candidate
        if value > candidatePeakValue {
            candidatePeakValue = value
            candidatePeakTime = timestamp
            return nil
        }

        // confirm peak when signal drops enough
        let dropFromPeak = candidatePeakValue - value
        if dropFromPeak >= config.fallDelta {

            let prominence = candidatePeakValue - baseline

            if let last = lastRepTime {
                let interval = candidatePeakTime - last
                if interval < config.minRepInterval {
                    resetCandidate(to: value, at: timestamp)
                    return nil
                }
                if interval > config.maxRepInterval {
                    lastRepTime = nil
                }
            }

            if prominence >= config.minProminence {
                guard peakGyroMagnitude >= config.minGyroMagnitude else {
                    resetCandidate(to: value, at: timestamp)
                    return nil
                }

                let interval = lastRepTime.map { candidatePeakTime - $0 }
                lastRepTime = candidatePeakTime

                // ✅ Arm off until we drop enough again
                lastCountedPeakValue = candidatePeakValue
                isArmedForNextRep = false

                let event = RepEvent(
                    timestamp: candidatePeakTime,
                    peakValue: candidatePeakValue,
                    baselineValue: baseline,
                    prominence: prominence,
                    repInterval: interval
                )

                resetCandidate(to: value, at: timestamp)
                return event
            } else {
                resetCandidate(to: value, at: timestamp)
                return nil
            }
        }

        return nil
    }

    private func resetCandidate(to value: Double, at timestamp: TimeInterval) {
        candidatePeakValue = value
        candidatePeakTime = timestamp
        peakGyroMagnitude = 0
    }

    private func updateBaseline(timestamp: TimeInterval, value: Double) {
        let dt: Double
        if let last = lastTimestamp {
            dt = max(1e-6, timestamp - last)
        } else {
            dt = 1.0 / 50.0
        }
        lastTimestamp = timestamp

        let tau = max(1e-6, config.baselineTau)
        let alpha = dt / (tau + dt)

        if !baselineInitialized {
            baseline = value
            baselineInitialized = true
        } else {
            baseline = alpha * value + (1 - alpha) * baseline
        }
    }
}

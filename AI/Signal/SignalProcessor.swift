import Foundation

/// A compact “processed sample” used by the sensor+logic pipeline.
/// This is what your rep/set logic will work with (not raw xyz every time).
struct ProcessedMotion {
    let timestamp: TimeInterval

    // Raw (from MotionSample)
    let acc: Vector3          // userAcceleration
    let gyro: Vector3         // rotationRate
    let gravity: Vector3      // ✅ gravity (unit-ish)

    // Derived
    let accMag: Double
    let gyroMag: Double

    /// Orientation (radians)
    let pitch: Double         // ✅
    let roll: Double          // ✅

    // Filtered (low-pass)
    let accMagLP: Double
    let gyroMagLP: Double
    let pitchLP: Double       // ✅
    let rollLP: Double        // ✅
}

/// Phase A Step 2: signal processing (no rep logic, no ML).
/// - Computes magnitudes
/// - Computes pitch/roll from gravity
/// - Applies a lightweight low-pass filter (EMA)
/// - Maintains rolling history
final class SignalProcessor {

    struct Config {
        var targetHz: Double = 50.0
        var lowPassTimeConstant: Double = 0.25
        var historySeconds: Double = 6.0

        init(targetHz: Double = 50.0,
             lowPassTimeConstant: Double = 0.25,
             historySeconds: Double = 6.0) {
            self.targetHz = targetHz
            self.lowPassTimeConstant = lowPassTimeConstant
            self.historySeconds = historySeconds
        }
    }

    private(set) var config: Config

    // Filter state
    private var lastTimestamp: TimeInterval?
    private var accLP: Double = 0
    private var gyroLP: Double = 0
    private var pitchLPState: Double = 0
    private var rollLPState: Double = 0
    private var initialized = false

    // Rolling history
    private var history: RingBuffer<ProcessedMotion>

    init(config: Config = Config()) {
        self.config = config
        let cap = max(10, Int(config.historySeconds * config.targetHz))
        self.history = RingBuffer<ProcessedMotion>(capacity: cap)
    }

    func updateConfig(_ newConfig: Config) {
        self.config = newConfig
        let cap = max(10, Int(newConfig.historySeconds * newConfig.targetHz))
        var newHistory = RingBuffer<ProcessedMotion>(capacity: cap)
        for v in history.values.suffix(cap) { newHistory.append(v) }
        self.history = newHistory
    }

    func reset() {
        lastTimestamp = nil
        accLP = 0
        gyroLP = 0
        pitchLPState = 0
        rollLPState = 0
        initialized = false
        history.removeAll()
    }

    func process(sample: MotionSample) -> ProcessedMotion {
        let t = sample.timestamp
        let acc = sample.userAcceleration
        let gyro = sample.rotationRate
        let g = sample.gravity

        let accMag = magnitude(of: acc)
        let gyroMag = magnitude(of: gyro)

        // ✅ pitch/roll from gravity (radians)
        let pitch = gravityPitch(g)
        let roll  = gravityRoll(g)

        // dt for EMA
        let dt: Double
        if let last = lastTimestamp {
            dt = max(1e-6, t - last)
        } else {
            dt = 1.0 / max(1.0, config.targetHz)
        }
        lastTimestamp = t

        let alpha = emaAlpha(dt: dt, tau: config.lowPassTimeConstant)

        if !initialized {
            accLP = accMag
            gyroLP = gyroMag
            pitchLPState = pitch
            rollLPState = roll
            initialized = true
        } else {
            accLP = alpha * accMag + (1 - alpha) * accLP
            gyroLP = alpha * gyroMag + (1 - alpha) * gyroLP

            // ✅ angle LP (works fine for small changes; for huge wrap you’d want unwrap)
            pitchLPState = alpha * pitch + (1 - alpha) * pitchLPState
            rollLPState  = alpha * roll  + (1 - alpha) * rollLPState
        }

        let processed = ProcessedMotion(
            timestamp: t,
            acc: acc,
            gyro: gyro,
            gravity: g,
            accMag: accMag,
            gyroMag: gyroMag,
            pitch: pitch,
            roll: roll,
            accMagLP: accLP,
            gyroMagLP: gyroLP,
            pitchLP: pitchLPState,
            rollLP: rollLPState
        )

        history.append(processed)
        return processed
    }

    func recentHistory() -> [ProcessedMotion] {
        history.values
    }

    // MARK: - Helpers

    private func magnitude(of v: Vector3) -> Double {
        (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
    }

    /// pitch in radians
    /// Common formula: atan2(-gx, sqrt(gy^2 + gz^2))
    private func gravityPitch(_ g: Vector3) -> Double {
        atan2(-g.x, (g.y * g.y + g.z * g.z).squareRoot())
    }

    /// roll in radians
    /// Common formula: atan2(gy, gz)
    private func gravityRoll(_ g: Vector3) -> Double {
        atan2(g.y, g.z)
    }

    private func emaAlpha(dt: Double, tau: Double) -> Double {
        let tauClamped = max(1e-6, tau)
        return dt / (tauClamped + dt)
    }
}

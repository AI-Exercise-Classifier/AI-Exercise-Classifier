import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor
final class LiveWorkoutViewModel: ObservableObject {

    // MARK: UI
    @Published private(set) var isTracking: Bool = false
    @Published private(set) var sampleCount: Int = 0
    @Published private(set) var estimatedHz: Double = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    // Always 100 Hz (UI can ignore)
    @Published var selectedHz: Double = 100.0

    // Watch state (kept, but not shown in your clean UI)
    @Published private(set) var isWatchStreaming: Bool = false
    @Published private(set) var watchHz: Double = 0
    @Published private(set) var lastBatchSize: Int = 0
    @Published private(set) var batchCount: Int = 0
    @Published private(set) var lastBatchReceivedAt: Date = .distantPast

    // ML state
    @Published private(set) var mlIsReady: Bool = false
    @Published private(set) var lastPredictionAt: TimeInterval = 0
    @Published var bypassActivityGate: Bool = true
    @Published private(set) var gateReason: String = "-"

    // Sensors (optional to show)
    @Published private(set) var latestSample: MotionSample?
    @Published private(set) var accMagLP: Double = 0
    @Published private(set) var gyroMagLP: Double = 0

    // Activity (motion/noise)
    @Published private(set) var activityState: ActivityDetector.State = .resting
    @Published private(set) var isActive: Bool = false

    // Prediction output
    @Published private(set) var predictedExercise: String = "idle"
    @Published private(set) var predictedConfidence: Double = 1.0
    @Published private(set) var mlRawLabel: String = "-"
    @Published private(set) var mlRawConfidence: Double = 0.0

    // MARK: Reps / Set (UI)
    @Published private(set) var currentReps: Int = 0
    @Published private(set) var lastRepAt: TimeInterval = 0

    /// UI-only: reps detected before ML locks the label (shown as +N)
    @Published private(set) var pendingRepsUI: Int = 0

    @Published var weightKg: Double = 10.0
    @Published private(set) var currentExercise: String = "idle"
    @Published private(set) var currentSetIndex: Int = 0

    /// Saved sets during this session (NOT persisted here; you persist on stop)
    @Published private(set) var completedSets: [WorkoutHistoryStore.CompletedSet] = []

    // MARK: Internals
    private var sessionStartTimestamp: TimeInterval?
    private var lastSampleTimestamp: TimeInterval?
    private var elapsedTimer: AnyCancellable?
    private var resendTimer: AnyCancellable?

    private var signalProcessor: SignalProcessor?
    private var activityDetector: ActivityDetector?
    private let repDetector = RepDetector()

    private var classifier: ExerciseClassifierService?
    private var mlStrideCounter: Int = 0
    private let mlStride: Int = 25

    private var isExerciseMode: Bool = false
    private var lockedLabel: String = "idle"
    private var lastStrongPredictionAt: TimeInterval = 0

    private let enterExercise: Double = 0.60
    private let exitExercise: Double  = 0.45
    private let holdSeconds: TimeInterval = 1.0

    // set tracking
    private var currentSetStartTs: TimeInterval?
    private var currentSetConfSum: Double = 0
    private var currentSetConfCount: Int = 0
    private var setIndexByExercise: [String: Int] = [:]

    // pending reps before ML locks
    private var pendingReps: Int = 0
    private var pendingLastRepTs: TimeInterval = 0
    private let pendingWindowSeconds: TimeInterval = 1.2

    // fallback exit
    private let fallbackExitExtra: TimeInterval = 0.6

    private var startedAtDate: Date?
    private let watchLiveReceiver = PhoneWatchReceiver.shared

    // MARK: Public API

    func startTracking() {
        guard !isTracking else { return }
        resetSessionState()

        isTracking = true
        startedAtDate = Date()

        // Always 100
        selectedHz = 100.0

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        signalProcessor = SignalProcessor()
        activityDetector = ActivityDetector()

        repDetector.reset()

        classifier = ExerciseClassifierService(windowSize: 200)
        classifier?.reset()

        signalProcessor?.updateConfig(.init(
            targetHz: selectedHz,
            lowPassTimeConstant: 0.25,
            historySeconds: 6.0
        ))
        signalProcessor?.reset()
        activityDetector?.reset()

        elapsedTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard let start = self.sessionStartTimestamp else { return }
                if let last = self.lastSampleTimestamp {
                    self.elapsedSeconds = max(0, last - start)
                }
            }

        isWatchStreaming = true
        watchLiveReceiver.startListening { [weak self] (samples: [MotionSample], hz: Double) in
            guard let self else { return }

            self.watchHz = hz
            self.lastBatchSize = samples.count
            self.batchCount += 1
            self.lastBatchReceivedAt = Date()
            self.estimatedHz = hz

            self.resendTimer?.cancel()
            self.resendTimer = nil

            for s in samples { self.handle(sample: s) }
        }

        sendStartStreamWithRetry()
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif

        resendTimer?.cancel()
        resendTimer = nil

        watchLiveReceiver.sendStopStream()
        watchLiveReceiver.stopListening()
        isWatchStreaming = false

        elapsedTimer?.cancel()
        elapsedTimer = nil

        // finish running set
        finishSetIfNeeded(endTs: lastSampleTimestamp ?? 0)
        clearPending()

        // persist workout history (if you already have WorkoutHistoryStore)
        if let startDate = startedAtDate {
            let summary = WorkoutHistoryStore.shared.makeSessionSummary(
                startedAt: startDate,
                endedAt: Date(),
                sets: completedSets
            )
            WorkoutHistoryStore.shared.addSession(summary)
        }
        startedAtDate = nil

        predictedExercise = "idle"
        predictedConfidence = 1.0
        mlRawLabel = "-"
        mlRawConfidence = 0.0
        gateReason = "stopped"

        classifier?.reset()
        classifier = nil
    }

    // MARK: Private helpers

    private func sendStartStreamWithRetry() {
        watchLiveReceiver.sendStartStream(hz: selectedHz)

        resendTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.isTracking else { return }
                if self.batchCount == 0 {
                    self.watchLiveReceiver.sendStartStream(hz: self.selectedHz)
                }
            }
    }

    private func handle(sample: MotionSample) {
        guard let signalProcessor, let activityDetector, let classifier else { return }

        latestSample = sample
        sampleCount += 1

        if sessionStartTimestamp == nil { sessionStartTimestamp = sample.timestamp }
        if let last = lastSampleTimestamp {
            let dt = sample.timestamp - last
            if dt > 0 { estimatedHz = 1.0 / dt }
        }
        lastSampleTimestamp = sample.timestamp

        let p = signalProcessor.process(sample: sample)

        let st = activityDetector.update(timestamp: p.timestamp, motionValue: p.accMagLP)
        activityState = st
        isActive = (st == .active)

        accMagLP = p.accMagLP
        gyroMagLP = p.gyroMagLP

        // ✅ REP DETECTOR runs on EVERY sample
        // Only detect reps:
        // - in exercise, OR
        // - (pre-exercise) while idle+active AND ML is ready (reduces false pending reps)
        let shouldDetectReps = isExerciseMode || (predictedExercise == "idle" && isActive && mlIsReady)

        if let rep = repDetector.update(
            timestamp: p.timestamp,
            value: abs(p.pitchLP),  
            gyroMagLP: p.gyroMagLP,
            shouldCountReps: shouldDetectReps
        ) {
            lastRepAt = rep.timestamp

            if isExerciseMode && lockedLabel != "idle" {
                currentReps += 1
            } else {
                // buffer until ML locks label
                pendingReps += 1
                pendingLastRepTs = rep.timestamp
                pendingRepsUI = pendingReps
            }
        }

        // ✅ pending timeout (so old noise doesn't seed next set)
        if pendingReps > 0, (p.timestamp - pendingLastRepTs) > pendingWindowSeconds {
            clearPending()
        }

        classifier.append(sample)
        mlIsReady = classifier.isReady
        mlStrideCounter += 1

        // ✅ fallback exit if ML “stalls”
        if isExerciseMode && (p.timestamp - lastStrongPredictionAt) > (holdSeconds + fallbackExitExtra) {
            finishSetIfNeeded(endTs: p.timestamp)
            setExerciseMode(false, newLabel: "idle", conf: 1.0, ts: p.timestamp)
            gateReason = "fallback_exit"
        }

        // warmup
        guard classifier.isReady else {
            gateReason = "warming_up \(min(sampleCount, 200))/200"
            return
        }

        // ML stride gate
        guard mlStrideCounter % mlStride == 0 else {
            gateReason = "stride_wait"
            return
        }

        do {
            let (rawLabel, conf, top) = try classifier.predictTopK(5)

            mlRawLabel = rawLabel + " | top: " + top.map { "\($0.0)=\(String(format:"%.2f",$0.1))" }.joined(separator: ", ")
            mlRawConfidence = conf
            lastPredictionAt = sample.timestamp

            let norm = normalizeLabel(rawLabel)
            let nowTs = sample.timestamp

            if !bypassActivityGate && !isActive {
                gateReason = "activity_gate"
                finishSetIfNeeded(endTs: nowTs)
                setExerciseMode(false, newLabel: "idle", conf: 1.0, ts: nowTs)
                return
            }

            if !isExerciseMode {
                if conf >= enterExercise && norm != "idle" {
                    setExerciseMode(true, newLabel: norm, conf: conf, ts: nowTs)
                    gateReason = "enter \(norm)"
                } else {
                    gateReason = "below_enter"
                    // keep idle (don’t clear pending immediately; pending timeout will handle it)
                    predictedExercise = "idle"
                    predictedConfidence = 1.0
                }
            } else {
                if conf >= exitExercise && norm != "idle" {
                    lockedLabel = norm
                    currentExercise = lockedLabel
                    lastStrongPredictionAt = nowTs
                    predictedExercise = lockedLabel
                    predictedConfidence = conf

                    currentSetConfSum += conf
                    currentSetConfCount += 1
                    gateReason = "update \(norm)"
                } else if nowTs - lastStrongPredictionAt > holdSeconds {
                    finishSetIfNeeded(endTs: nowTs)
                    setExerciseMode(false, newLabel: "idle", conf: 1.0, ts: nowTs)
                    gateReason = "hold_timeout"
                }
            }

        } catch {
            gateReason = "predict_error: \(error.localizedDescription)"
            print("❌ ML predict error:", error)
        }
    }

    // MARK: - Exercise mode helpers

    private func setExerciseMode(_ enabled: Bool, newLabel: String, conf: Double, ts: TimeInterval) {
        isExerciseMode = enabled

        if enabled {
            lockedLabel = newLabel
            currentExercise = newLabel
            lastStrongPredictionAt = ts

            let next = (setIndexByExercise[newLabel] ?? 0) + 1
            setIndexByExercise[newLabel] = next
            currentSetIndex = next

            predictedExercise = lockedLabel
            predictedConfidence = conf

            // ✅ seed reps with pending reps so “first rep” isn’t lost
            currentReps = pendingReps
            lastRepAt = pendingLastRepTs
            clearPending()

            // IMPORTANT: do NOT reset repDetector here (it would drop timing/baseline)
            // repDetector.reset()  ❌

            currentSetStartTs = ts
            currentSetConfSum = conf
            currentSetConfCount = 1
        } else {
            lockedLabel = "idle"
            currentExercise = "idle"
            currentSetIndex = 0

            predictedExercise = "idle"
            predictedConfidence = 1.0

            currentSetStartTs = nil
            currentSetConfSum = 0
            currentSetConfCount = 0

            clearPending()
        }
    }

    private func finishSetIfNeeded(endTs: TimeInterval) {
        guard let start = currentSetStartTs else { return }
        let ex = lockedLabel
        guard ex != "idle" else { return }

        let reps = currentReps
        guard reps > 0 else {
            // don’t save 0-rep sets
            currentSetStartTs = nil
            currentSetConfSum = 0
            currentSetConfCount = 0
            return
        }

        let avgConf = (currentSetConfCount > 0)
            ? (currentSetConfSum / Double(currentSetConfCount))
            : predictedConfidence

        let idx = setIndexByExercise[ex] ?? 1

        completedSets.append(.init(
            exercise: ex,
            setIndex: idx,
            reps: reps,
            weightKg: weightKg,
            startedAt: start,
            endedAt: endTs,
            avgConfidence: avgConf
        ))

        currentSetStartTs = nil
        currentSetConfSum = 0
        currentSetConfCount = 0
    }

    private func clearPending() {
        pendingReps = 0
        pendingLastRepTs = 0
        pendingRepsUI = 0
    }

    private func normalizeLabel(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func resetSessionState() {
        sessionStartTimestamp = nil
        lastSampleTimestamp = nil

        sampleCount = 0
        estimatedHz = 0
        elapsedSeconds = 0

        latestSample = nil
        accMagLP = 0
        gyroMagLP = 0

        activityState = .resting
        isActive = false

        predictedExercise = "idle"
        predictedConfidence = 1.0
        mlRawLabel = "-"
        mlRawConfidence = 0.0

        isExerciseMode = false
        lockedLabel = "idle"
        currentExercise = "idle"
        currentSetIndex = 0
        lastStrongPredictionAt = 0

        mlStrideCounter = 0
        mlIsReady = false
        lastPredictionAt = 0
        gateReason = "-"

        isWatchStreaming = false
        watchHz = 0
        lastBatchSize = 0
        batchCount = 0
        lastBatchReceivedAt = .distantPast

        currentReps = 0
        lastRepAt = 0
        completedSets.removeAll()

        currentSetStartTs = nil
        currentSetConfSum = 0
        currentSetConfCount = 0
        setIndexByExercise.removeAll()

        clearPending()

        repDetector.reset()

        resendTimer?.cancel()
        resendTimer = nil
        startedAtDate = nil
    }
}

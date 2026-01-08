import Foundation
import Combine

@MainActor
final class WorkoutSessionViewModel: ObservableObject {

    @Published private(set) var isCollectingData = false
    @Published private(set) var sampleCount = 0
    @Published private(set) var estimatedHz: Double = 0
    @Published private(set) var lastSavedRecordingURL: URL?
    @Published var selectedHz: Double = 100.0

    @Published var dataSource: DataSource = .phone

    private let motionService = MotionService()
    private let recorder = DataRecordingService()
    private var lastTimestamp: TimeInterval?

    private let watch = PhoneWatchReceiver.shared

    init() {
        // ✅ CSV från watch (transferFile)
        watch.startListeningForFiles { [weak self] (localURL, metadata) in
            guard let self else { return }
            self.lastSavedRecordingURL = localURL
            self.isCollectingData = false
            print("✅ got CSV:", localURL.lastPathComponent, "meta:", metadata ?? [:])
        }

        // (VALFRITT) om din PhoneWatchReceiver har startListeningForAcks(...)
        watch.startListeningForAcks { type, payload in
            print("📱 ACK:", type, payload)
        }
    }

    func startDataCollection(label: ExerciseType,
                             placement: PhonePlacement,
                             sessionID: String,
                             personID: String) {
        guard !isCollectingData else { return }

        isCollectingData = true
        sampleCount = 0
        estimatedHz = 0
        lastSavedRecordingURL = nil
        lastTimestamp = nil

        switch dataSource {
        case .phone:
            recorder.start(label: label, placement: placement, sessionID: sessionID, personID: personID)

            motionService.startStreaming(updateHz: selectedHz) { [weak self] sample in
                guard let self else { return }
                Task { @MainActor in
                    self.recorder.append(sample)
                    self.sampleCount += 1

                    if let last = self.lastTimestamp {
                        let dt = sample.timestamp - last
                        if dt > 0 { self.estimatedHz = 1.0 / dt }
                    }
                    self.lastTimestamp = sample.timestamp
                }
            }

        case .watch:
            estimatedHz = selectedHz

            // 1) start watch recording
            watch.sendStartRecording(hz: selectedHz, label: label.rawValue)

            // 2) (rekommenderat) start live stream för att visa sampleCount/Hz live
            watch.startListening { [weak self] (samples: [MotionSample], hz: Double) in
                guard let self else { return }
                Task { @MainActor in
                    self.sampleCount += samples.count
                    self.estimatedHz = hz
                }
            }
            watch.sendStartStream(hz: selectedHz)
        }
    }

    func stopDataCollection() {
        guard isCollectingData else { return }

        switch dataSource {
        case .phone:
            isCollectingData = false
            motionService.stopStreaming()
            do {
                lastSavedRecordingURL = try recorder.stopAndSave()
            } catch {
                print("Save error:", error)
            }

        case .watch:
            // stop live stream
            watch.sendStopStream()
            watch.stopListening()

            // stop watch recording -> fil kommer senare via transferFile
            watch.sendStopRecording()
 
            // ✅ låt UI fortsätta visa “samlar data” tills filen faktiskt kommer
            // (isCollectingData sätts false i file-callbacken)
        }
    }
}

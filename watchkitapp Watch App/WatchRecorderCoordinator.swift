import Foundation
import CoreMotion
import WatchConnectivity
import Combine

@MainActor
final class WatchRecorderCoordinator: NSObject {

    static let shared = WatchRecorderCoordinator()

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private var fileHandle: FileHandle?
    private var fileURL: URL?
    private var isRecording = false
    private var label: String = ""
    private var hz: Double = 100.0

    // ✅ håll transfer starkt tills systemet är klart
    private var pendingTransfer: WCSessionFileTransfer?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()

        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1

        // ✅ se till att WC delegate finns
        _ = WatchCommandReceiver.shared

        // ✅ lyssna på commands (från WatchCommandReceiver -> NotificationCenter)
        NotificationCenter.default.publisher(for: .watchRecordingStart)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self else { return }
                let hz = (note.userInfo?["hz"] as? Double) ?? 100.0
                let label = (note.userInfo?["label"] as? String) ?? "unknown"
                self.startRecording(hz: hz, label: label)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .watchRecordingStop)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.stopRecording()
            }
            .store(in: &cancellables)
    }

    func startRecording(hz: Double, label: String) {
        guard !isRecording else {
            print("⚠️ Recording already running")
            return
        }
        guard manager.isDeviceMotionAvailable else {
            print("❌ DeviceMotion not available")
            return
        }

        self.hz = hz
        self.label = label
        isRecording = true

        // ✅ skapa fil
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let name = "watch_motion_\(label)_\(Int(hz))hz_\(timestampString()).csv"
            let url = docs.appendingPathComponent(name)

            FileManager.default.createFile(atPath: url.path, contents: nil)
            fileURL = url
            fileHandle = try FileHandle(forWritingTo: url)

            // ✅ HEADER UTAN LABEL
            try fileHandle?.write(contentsOf: Data("timestamp,ax,ay,az,gx,gy,gz,grx,gry,grz\n".utf8))
        } catch {
            print("❌ file create error:", error)
            isRecording = false
            fileURL = nil
            fileHandle = nil
            return
        }

        manager.deviceMotionUpdateInterval = 1.0 / hz
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            if let error {
                print("❌ motion error:", error)
                return
            }
            guard let self, let m = motion, self.isRecording else { return }

            // ✅ RAD UTAN LABEL
            let row =
              "\(m.timestamp),\(m.userAcceleration.x),\(m.userAcceleration.y),\(m.userAcceleration.z)," +
              "\(m.rotationRate.x),\(m.rotationRate.y),\(m.rotationRate.z)," +
              "\(m.gravity.x),\(m.gravity.y),\(m.gravity.z)\n"

            do {
                try self.fileHandle?.write(contentsOf: Data(row.utf8))
            } catch {
                print("❌ write error:", error)
            }
        }

        // ✅ ACK som funkar även när reachability är tveksam
        WCSession.default.transferUserInfo(["type": "recordingStarted", "label": label, "hz": hz])

        print("⌚️ Recording STARTED label=\(label) hz=\(hz)")
    }

    func stopRecording() {
        guard isRecording else {
            print("⚠️ stopRecording called but not recording")
            return
        }

        isRecording = false
        manager.stopDeviceMotionUpdates()

        do { try fileHandle?.close() } catch {
            print("❌ close error:", error)
        }
        fileHandle = nil

        guard let url = fileURL else {
            print("❌ stopRecording: missing fileURL")
            return
        }
        fileURL = nil

        let session = WCSession.default
        if session.activationState != .activated { session.activate() }

        // ✅ transferFile (håll referensen!)
        pendingTransfer = session.transferFile(
            url,
            metadata: ["type": "training_csv_v1", "label": label, "hz": hz]
        )

        // ✅ ACK
        session.transferUserInfo(["type": "recordingStopped", "label": label])

        print("⌚️ Recording STOPPED -> transfer queued: \(url.lastPathComponent)")
    }

    private func timestampString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

#if os(iOS)
import Foundation
import WatchConnectivity
import Combine

@MainActor
final class PhoneWatchReceiver: NSObject, ObservableObject {

    static let shared = PhoneWatchReceiver()

    typealias BatchHandler = (_ samples: [MotionSample], _ hz: Double) -> Void
    private var onBatch: BatchHandler?

    typealias FileHandler = (_ localURL: URL, _ metadata: [String: Any]?) -> Void
    private var onFile: FileHandler?

    typealias AckHandler = (_ type: String, _ payload: [String: Any]) -> Void
    private var onAck: AckHandler?

    private override init() {
        super.init()
        activateIfNeeded()
    }

    func startListening(_ onBatch: @escaping BatchHandler) { self.onBatch = onBatch; activateIfNeeded() }
    func stopListening() { self.onBatch = nil }

    func startListeningForFiles(_ onFile: @escaping FileHandler) { self.onFile = onFile; activateIfNeeded() }
    func stopListeningForFiles() { self.onFile = nil }

    func startListeningForAcks(_ onAck: @escaping AckHandler) { self.onAck = onAck; activateIfNeeded() }
    func stopListeningForAcks() { self.onAck = nil }

    // MARK: Commands phone -> watch

    func sendStartStream(hz: Double) { send(["type":"startStream","hz":hz]) }
    func sendStopStream() { send(["type":"stopStream"]) }
    func sendStartRecording(hz: Double, label: String) { send(["type":"startRecording","hz":hz,"label":label]) }
    func sendStopRecording() { send(["type":"stopRecording"]) }

    private func send(_ payload: [String: Any]) {
        activateIfNeeded()
        let s = WCSession.default
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { _ in
                s.transferUserInfo(payload)
            }
        } else {
            s.transferUserInfo(payload)
        }
    }

    private func activateIfNeeded() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.delegate !== self { s.delegate = self }
        if s.activationState != .activated { s.activate() }
    }

    // MARK: - SYNC file copy helper (viktig!)

    nonisolated private static func copyWatchFileImmediately(_ file: WCSessionFile) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!

        let src = file.fileURL
        var dst = docs.appendingPathComponent(src.lastPathComponent)

        if fm.fileExists(atPath: dst.path) {
            let base = dst.deletingPathExtension().lastPathComponent
            let ext = dst.pathExtension
            dst = docs.appendingPathComponent("\(base)_\(Int(Date().timeIntervalSince1970)).\(ext)")
        }

        // ✅ Kopiera direkt (innan callback returnerar)
        try fm.copyItem(at: src, to: dst)

        // städa temp best-effort (kan faila, ok)
        try? fm.removeItem(at: src)

        return dst
    }

    // MARK: Message decoding (motion + ack)
    nonisolated private func handleAnyMessage(_ payload: [String: Any]) {
        let type = payload["type"] as? String ?? "nil"

        if type == "recordingStarted" || type == "recordingStopped" {
            Task { @MainActor in self.onAck?(type, payload) }
            return
        }

        guard type == "motionBatch_v2" else { return }

        let hz = (payload["hz"] as? Double) ?? 100.0
        let stride = (payload["stride"] as? Int) ?? 10
        guard stride == 10,
              let data = payload["data"] as? [Double],
              data.count % 10 == 0 else { return }

        Task { @MainActor [data, hz] in
            var parsed: [MotionSample] = []
            parsed.reserveCapacity(data.count / 10)

            var i = 0
            while i + 9 < data.count {
                let t   = data[i]
                let ax  = data[i+1], ay  = data[i+2], az  = data[i+3]
                let gx  = data[i+4], gy  = data[i+5], gz  = data[i+6]
                let grx = data[i+7], gry = data[i+8], grz = data[i+9]
                i += 10

                parsed.append(MotionSample(
                    timestamp: t,
                    userAcceleration: .init(x: ax, y: ay, z: az),
                    rotationRate: .init(x: gx, y: gy, z: gz),
                    gravity: .init(x: grx, y: gry, z: grz)
                ))
            }

            self.onBatch?(parsed, hz)
        }
    }
}

extension PhoneWatchReceiver: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error { print("❌ iPhone WC activate error:", error) }
        print("✅ iPhone WC activated:", activationState.rawValue,
              "watchInstalled=\(session.isWatchAppInstalled)",
              "paired=\(session.isPaired)")
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleAnyMessage(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleAnyMessage(userInfo)
    }

    // ✅ FIX: kopiera filen DIREKT här (inte via Task/MainActor)
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        do {
            let localURL = try Self.copyWatchFileImmediately(file)
            let meta = file.metadata

            Task { @MainActor in
                print("✅ iPhone received file:", localURL.lastPathComponent, "meta:", meta ?? [:])
                self.onFile?(localURL, meta)
            }
        } catch {
            print("❌ copyWatchFileImmediately failed:", error)
        }
    }
}
#endif

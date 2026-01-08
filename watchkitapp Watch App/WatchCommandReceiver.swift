import Foundation
import WatchConnectivity

final class WatchCommandReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchCommandReceiver()

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default

        // ✅ bara en delegate får finnas – denna klass ska vara den
        if s.delegate !== self { s.delegate = self }

        if s.activationState != .activated {
            s.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error { print("❌ Watch WC activate error:", error) }
        print("✅ Watch WC activated:",
              "state=\(activationState.rawValue)",
              "reachable=\(session.isReachable)")
    }

    // ✅ live command (när iPhone är reachable)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        route(message, source: "didReceiveMessage")
    }

    // ✅ background command (transferUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        route(userInfo, source: "didReceiveUserInfo")
    }

    // ✅ callback när transferFile är KLAR eller FAILAR
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let filename = fileTransfer.file.fileURL.lastPathComponent

        var info: [String: Any] = [
            "file": filename,
            "success": (error == nil)
        ]
        if let error { info["error"] = error.localizedDescription }

        if let error {
            print("❌ transferFile finished ERROR:", filename, error.localizedDescription)
        } else {
            print("✅ transferFile finished OK:", filename)
        }

        // ✅ skicka till resten av appen (WatchRecorderCoordinator kan lyssna)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .watchFileTransferFinished,
                object: nil,
                userInfo: info
            )
        }
    }

    // MARK: - Routing

    private func route(_ msg: [String: Any], source: String) {
        guard let type = msg["type"] as? String else {
            print("⚠️ \(source) missing 'type':", msg)
            return
        }

        DispatchQueue.main.async {
            switch type {
            case "startStream":
                NotificationCenter.default.post(name: .watchCommandStart, object: nil, userInfo: msg)

            case "stopStream":
                NotificationCenter.default.post(name: .watchCommandStop, object: nil)

            case "startRecording":
                NotificationCenter.default.post(name: .watchRecordingStart, object: nil, userInfo: msg)

            case "stopRecording":
                NotificationCenter.default.post(name: .watchRecordingStop, object: nil)

            default:
                print("⚠️ WatchCommandReceiver unknown type:", type, "msg:", msg)
            }
        }
    }
}

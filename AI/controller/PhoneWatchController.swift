import Foundation
import WatchConnectivity

enum PhoneWatchController {

    static func activateIfNeeded() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.activationState != .activated { s.activate() }
    }

    static func startRecording(hz: Double, label: String) {
        activateIfNeeded()
        let s = WCSession.default

        let msg: [String: Any] = [
            "type": "startRecording",
            "hz": hz,
            "label": label
        ]

        // Om reachable: direkt. Annars: transferUserInfo så watch får kommandot ändå.
        if s.isReachable {
            s.sendMessage(msg, replyHandler: nil) { err in
                print("❌ startRecording sendMessage error:", err)
            }
        } else {
            s.transferUserInfo(msg)
        }
    }

    static func stopRecording() {
        activateIfNeeded()
        let s = WCSession.default

        let msg: [String: Any] = ["type": "stopRecording"]

        if s.isReachable {
            s.sendMessage(msg, replyHandler: nil) { err in
                print("❌ stopRecording sendMessage error:", err)
            }
        } else {
            s.transferUserInfo(msg)
        }
    }
}

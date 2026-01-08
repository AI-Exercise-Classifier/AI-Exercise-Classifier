import Foundation
import WatchConnectivity

@MainActor
final class MotionBatcher {

    private let hz: Double
    private let batchSize: Int
    private let stride = 10

    private var buffer: [Double] = []
    private var lastLiveSendTime: TimeInterval = 0
    private var lastQueuedSendTime: TimeInterval = 0

    /// Live (sendMessage) kan vara lite tätare
    var minLiveInterval: TimeInterval = 0.20   // 5 Hz max

    /// transferUserInfo MÅSTE vara glesare annars köar du ihjäl systemet
    var minQueuedInterval: TimeInterval = 0.80 // ~1.25 Hz

    init(hz: Double, batchSize: Int) {
        self.hz = hz
        self.batchSize = max(1, batchSize)
        buffer.reserveCapacity(self.batchSize * stride)
        activateIfNeeded()
    }

    // ✅ INTE private (så du inte får "inaccessible due to private")
    func activateIfNeeded() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.activationState != .activated { s.activate() }
    }

    func append(_ s: MotionSample) {
        activateIfNeeded()

        buffer.append(s.timestamp)
        buffer.append(s.userAcceleration.x)
        buffer.append(s.userAcceleration.y)
        buffer.append(s.userAcceleration.z)
        buffer.append(s.rotationRate.x)
        buffer.append(s.rotationRate.y)
        buffer.append(s.rotationRate.z)
        buffer.append(s.gravity.x)
        buffer.append(s.gravity.y)
        buffer.append(s.gravity.z)

        if buffer.count >= batchSize * stride {
            flush()
        }
    }

    func flush() {
        guard !buffer.isEmpty else { return }
        activateIfNeeded()

        let session = WCSession.default
        let now = Date().timeIntervalSince1970

        // kopiera ut batchen
        let dataCopy = buffer
        buffer.removeAll(keepingCapacity: true)

        let payload: [String: Any] = [
            "type": "motionBatch_v2",
            "hz": hz,
            "stride": stride,
            "data": dataCopy
        ]

        // 1) Live om reachable OCH inte throttlad
        if session.isReachable {
            if now - lastLiveSendTime >= minLiveInterval {
                lastLiveSendTime = now

                session.sendMessage(payload, replyHandler: nil) { err in
                    // live fail -> försök köa (throttlad)
                    Task { @MainActor in
                        self.queue(payload, because: "sendMessage failed: \(err.localizedDescription)")
                    }
                }
                return
            } else {
                // ✅ reachable men throttlad -> lägg tillbaka i buffern (inte transferUserInfo)
                buffer.append(contentsOf: dataCopy)
                return
            }
        }

        // 2) Inte reachable -> queue (throttlad)
        queue(payload, because: "not reachable")
    }

    private func queue(_ payload: [String: Any], because: String) {
        let now = Date().timeIntervalSince1970
        guard now - lastQueuedSendTime >= minQueuedInterval else {
            // queue throttlad -> lägg tillbaka data i buffern
            if let arr = payload["data"] as? [Double] {
                buffer.append(contentsOf: arr)
            }
            return
        }
        lastQueuedSendTime = now

        WCSession.default.transferUserInfo(payload)
        // print("📦 watch transferUserInfo (\(because))")
    }
}

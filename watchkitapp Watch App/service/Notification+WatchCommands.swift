import Foundation

extension Notification.Name {
    static let watchCommandStart = Notification.Name("watchCommandStart")
    static let watchCommandStop  = Notification.Name("watchCommandStop")

    static let watchRecordingStart = Notification.Name("watchRecordingStart")
    static let watchRecordingStop  = Notification.Name("watchRecordingStop")

    // ✅ behövs för CSV-transfer
    static let watchFileTransferFinished = Notification.Name("watchFileTransferFinished")
}

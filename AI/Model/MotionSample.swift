import Foundation

public struct Vector3: Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct MotionSample: Codable, Sendable {
    public let timestamp: TimeInterval
    public let userAcceleration: Vector3
    public let rotationRate: Vector3
    public let gravity: Vector3

    public init(timestamp: TimeInterval,
                userAcceleration: Vector3,
                rotationRate: Vector3,
                gravity: Vector3) {
        self.timestamp = timestamp
        self.userAcceleration = userAcceleration
        self.rotationRate = rotationRate
        self.gravity = gravity
    }
}

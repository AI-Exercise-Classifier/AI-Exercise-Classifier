import Foundation

final class DataRecordingService {
    private let ioQueue = DispatchQueue(label: "DataRecordingService.ioQueue")

    private var isRecording = false
    private var buffer: [MotionSample] = []

    private var label: ExerciseType = .unknown
    private var placement: PhonePlacement = .upperArm
    private var sessionID: String = ""
    private var personID: String = ""
    private var startedAt: Date = Date()

    func start(
        label: ExerciseType,
        placement: PhonePlacement,
        sessionID: String,
        personID: String
    ) {
        ioQueue.sync {
            self.isRecording = true
            self.buffer.removeAll(keepingCapacity: true)
            self.label = label
            self.placement = placement
            self.sessionID = sessionID
            self.personID = personID
            self.startedAt = Date()
        }
    }

    func append(_ sample: MotionSample) {
        ioQueue.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.buffer.append(sample)
        }
    }

    func stopAndSave() throws -> URL {
        let snapshot = ioQueue.sync {
            self.isRecording = false
            return (
                samples: self.buffer,
                label: self.label,
                placement: self.placement,
                sessionID: self.sessionID,
                personID: self.personID,
                startedAt: self.startedAt
            )
        }

        let filename = makeFilename(
            label: snapshot.label,
            placement: snapshot.placement,
            startedAt: snapshot.startedAt
        )

        let url = documentsURL(filename: filename)

        var rows: [String] = []
        rows.reserveCapacity(snapshot.samples.count + 1)

        // ✅ Header (always includes gravity)
        rows.append("timestamp,ax,ay,az,gx,gy,gz,grx,gry,grz,label")

        for s in snapshot.samples {
            let row =
            "\(s.timestamp)," +
            "\(s.userAcceleration.x),\(s.userAcceleration.y),\(s.userAcceleration.z)," +
            "\(s.rotationRate.x),\(s.rotationRate.y),\(s.rotationRate.z)," +
            "\(s.gravity.x),\(s.gravity.y),\(s.gravity.z)," +
            "\(snapshot.label.rawValue)"

            rows.append(row)
        }

        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers

    private func makeFilename(
        label: ExerciseType,
        placement: PhonePlacement,
        startedAt: Date
    ) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return "motion_\(label.rawValue)_\(placement.rawValue)_\(df.string(from: startedAt)).csv"
    }

    private func documentsURL(filename: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}

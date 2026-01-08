import Foundation
import Combine
import SwiftUI
@MainActor
final class WorkoutHistoryStore: ObservableObject {

    static let shared = WorkoutHistoryStore()

    // MARK: - Shared model (används av LiveWorkoutViewModel också)

    struct CompletedSet: Identifiable, Codable, Sendable {
        let id: UUID
        let exercise: String
        let setIndex: Int
        let reps: Int
        let weightKg: Double
        let startedAt: TimeInterval
        let endedAt: TimeInterval
        let avgConfidence: Double

        var volume: Double { Double(reps) * weightKg }

        init(id: UUID = UUID(),
             exercise: String,
             setIndex: Int,
             reps: Int,
             weightKg: Double,
             startedAt: TimeInterval,
             endedAt: TimeInterval,
             avgConfidence: Double) {
            self.id = id
            self.exercise = exercise
            self.setIndex = setIndex
            self.reps = reps
            self.weightKg = weightKg
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.avgConfidence = avgConfidence
        }
    }

    struct SessionSummary: Identifiable, Codable, Sendable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date
        let sets: [CompletedSet]

        var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
        var totalVolume: Double { sets.reduce(0) { $0 + $1.volume } }

        // ✅ sortera per övning + setIndex
        var setsByExercise: [String: [CompletedSet]] {
            let dict = Dictionary(grouping: sets, by: { $0.exercise })
            return dict.mapValues { $0.sorted { $0.setIndex < $1.setIndex } }
        }
    }

    // MARK: - State

    @Published private(set) var sessions: [SessionSummary] = []
    var lastSession: SessionSummary? { sessions.first }

    // MARK: - Persistence

    private let fileName = "workout_history_v1.json"

    private var fileURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ExerciseTracker", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    func addSession(_ session: SessionSummary) {
        sessions.insert(session, at: 0)
        saveToDisk()
    }

    func deleteSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        saveToDisk()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        saveToDisk()
    }

    func clearAll() {
        sessions.removeAll()
        saveToDisk()
    }

    // ✅ Bygger summary direkt från sets (utan att referera LiveWorkoutViewModel)
    func makeSessionSummary(startedAt: Date, endedAt: Date, sets: [CompletedSet]) -> SessionSummary {
        let filtered = sets.filter { $0.reps > 0 && $0.exercise != "idle" }
        return SessionSummary(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            sets: filtered
        )
    }

    // MARK: - Disk IO

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ WorkoutHistoryStore save error:", error)
        }
    }

    private func loadFromDisk() {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                sessions = []
                return
            }
            let data = try Data(contentsOf: url)
            sessions = try JSONDecoder().decode([SessionSummary].self, from: data)
        } catch {
            print("❌ WorkoutHistoryStore load error:", error)
            sessions = []
        }
    }
}

import SwiftUI
import Combine

@main
struct ExerciseTrackerApp: App {
    @StateObject private var sessionVM = WorkoutSessionViewModel()
    @StateObject private var history = WorkoutHistoryStore.shared

    init() {
        _ = PhoneWatchReceiver.shared
        _ = WorkoutHistoryStore.shared
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(sessionVM)
            .environmentObject(history)   // ✅ VIKTIGT
        }
    }
}

import SwiftUI

struct WatchStreamingView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @StateObject private var vm = WatchLiveWorkoutViewModel()

    var body: some View {
        VStack(spacing: 10) {
            Text("Watch AI")
                .font(.headline)

            Text(vm.isRunning ? "● LIVE" : "○ IDLE")
                .foregroundStyle(vm.isRunning ? .green : .secondary)

            Text(vm.isRunning ? "Streaming @ \(Int(vm.currentHz)) Hz" : "Waiting for phone…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .opacity(isLuminanceReduced ? 0.8 : 1.0)
        .saturation(isLuminanceReduced ? 0.7 : 1.0)
        .padding()
        .onAppear {
            // WC delegate tidigt
            _ = WatchCommandReceiver.shared
            _ = WatchRecorderCoordinator.shared  
        }
    }
}

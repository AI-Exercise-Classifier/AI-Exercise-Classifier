import SwiftUI

struct SummaryView: View {
    let summary: WorkoutSummary?

    var body: some View {
        VStack(spacing: 16) {
            Text("Summary")
                .font(.title).bold()

            if let summary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Date: \(summary.date.formatted(date: .abbreviated, time: .shortened))")
                    Text("Duration: \(formatDuration(summary.duration))")

                    Text("Reps:")
                        .font(.headline)

                    ForEach(summary.repsByExercise.sorted(by: { $0.key.rawValue < $1.key.rawValue }),
                            id: \.key) { ex, reps in
                        HStack {
                            Text(ex.displayName)
                            Spacer()
                            Text("\(reps)")
                                .monospacedDigit()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("No summary yet. Start and stop a workout to generate one.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

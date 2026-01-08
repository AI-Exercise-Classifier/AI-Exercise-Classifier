import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutHistoryStore.SessionSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout summary").font(.headline)

                        Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) → \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(AppTheme.subtext)

                        HStack(spacing: 12) {
                            StatPill(title: "Sets", value: "\(session.sets.count)", systemImage: "square.stack.3d.up")
                            StatPill(title: "Reps", value: "\(session.totalReps)", systemImage: "repeat")
                            StatPill(title: "Volume", value: String(format: "%.0f", session.totalVolume), systemImage: "scalemass")
                        }
                    }
                }

                ForEach(session.setsByExercise.keys.sorted(), id: \.self) { ex in
                    let sets = session.setsByExercise[ex] ?? []
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ex.capitalized).font(.headline)

                            ForEach(sets) { s in
                                HStack {
                                    Text("Set \(s.setIndex)")
                                    Spacer()
                                    Text("\(s.reps) reps · \(s.weightKg, specifier: "%.1f") kg")
                                }
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(AppTheme.subtext)
                            }

                            let exVol = sets.reduce(0.0) { $0 + $1.volume }
                            Text("Volume: \(exVol, specifier: "%.0f")")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
    }
}

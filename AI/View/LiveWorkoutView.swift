import SwiftUI

struct LiveWorkoutView: View {
    @StateObject private var vm = LiveWorkoutViewModel()

    private var groupedSets: [(exercise: String, sets: [WorkoutHistoryStore.CompletedSet])] {
        let dict = Dictionary(grouping: vm.completedSets, by: { $0.exercise })
        return dict
            .map { (exercise: $0.key, sets: $0.value.sorted { $0.setIndex < $1.setIndex }) }
            .sorted { $0.exercise < $1.exercise }
    }

    private var totalSets: Int { vm.completedSets.count }

    private var repsText: String {
        vm.pendingRepsUI > 0 ? "\(vm.currentReps) (+\(vm.pendingRepsUI))" : "\(vm.currentReps)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Current label
                AppCard {
                    VStack(spacing: 10) {
                        Text(vm.predictedExercise.capitalized)
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(vm.isTracking
                                             ? AnyShapeStyle(AppTheme.gradient)
                                             : AnyShapeStyle(AppTheme.subtext))

                        HStack(spacing: 10) {
                            pill(vm.isTracking ? "Tracking" : "Idle",
                                 systemImage: vm.isTracking ? "dot.radiowaves.left.and.right" : "pause.fill")
                            pill("100 Hz", systemImage: "speedometer")
                            pill("Conf \(String(format: "%.2f", vm.predictedConfidence))",
                                 systemImage: "chart.line.uptrend.xyaxis")
                        }

                        if vm.isTracking {
                            Text(vm.currentExercise == "idle"
                                 ? "Waiting for exercise…"
                                 : "\(vm.currentExercise.capitalized) · Set \(vm.currentSetIndex)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                // MARK: - Reps / Sets (always visible)
                HStack(spacing: 12) {
                    bigStat(title: "Reps", value: repsText, systemImage: "repeat")
                    bigStat(title: "Sets", value: "\(totalSets)", systemImage: "square.stack.3d.up")
                }

                // MARK: - Weight
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "scalemass")
                            Text("Weight")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.subtext)

                        HStack(alignment: .center, spacing: 12) {
                            Text("\(vm.weightKg, specifier: "%.1f") kg")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppTheme.text)

                            Spacer()

                            Stepper("", value: $vm.weightKg, in: 0...300, step: 2.5)
                                .labelsHidden()
                        }

                        Text("Applies to the next saved set")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                // MARK: - Start / Stop
                AppCard {
                    Button {
                        vm.isTracking ? vm.stopTracking() : vm.startTracking()
                    } label: {
                        Label(vm.isTracking ? "Stop workout" : "Start workout",
                              systemImage: vm.isTracking ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                // MARK: - Sets grouped by exercise (live)
                if vm.completedSets.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets")
                                .font(.headline)
                            Text("No sets saved yet. Complete a set and return to idle.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sets")
                            .font(.headline)

                        ForEach(groupedSets, id: \.exercise) { group in
                            AppCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.exercise.capitalized)
                                        .font(.headline)

                                    Divider().opacity(0.2)

                                    ForEach(group.sets) { s in
                                        HStack {
                                            Text("Set \(s.setIndex)")
                                                .font(.system(.subheadline, design: .monospaced))
                                                .foregroundStyle(AppTheme.subtext)
                                            Spacer()
                                            Text("\(s.reps) reps")
                                                .font(.system(.subheadline, design: .monospaced))
                                            Text("· \(s.weightKg, specifier: "%.1f") kg")
                                                .font(.system(.subheadline, design: .monospaced))
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Live Workout")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .onAppear { vm.selectedHz = 100.0 }
        .onDisappear { vm.stopTracking() }
    }

    // MARK: - Components

    private func pill(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.card.opacity(0.85))
        .clipShape(Capsule())
        .foregroundStyle(AppTheme.subtext)
    }

    private func bigStat(title: String, value: String, systemImage: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                    Text(title)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.subtext)

                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

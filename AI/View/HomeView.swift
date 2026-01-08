import SwiftUI

struct HomeView: View {
    @StateObject private var history = WorkoutHistoryStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exercise Tracker")
                            .font(.largeTitle.bold())
                        Text("Ready for your next set?")
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ✅ Last workout summary (om finns)
                    if let last = history.lastSession {
                        NavigationLink {
                            WorkoutSummaryView(session: last)
                        } label: {
                            AppCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Last workout").font(.headline)
                                        Text(last.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(AppTheme.subtext)
                                        Text("\(last.sets.count) sets • \(last.totalReps) reps • Vol \(Int(last.totalVolume))")
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppTheme.subtext)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        AppCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Last workout").font(.headline)
                                    Text("No workouts yet")
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                Spacer()
                            }
                        }
                    }

                    // ✅ History button
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Label("Workout History", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    NavigationLink {
                        DataCollectionView()
                    } label: {
                        Label("Data Collection", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    NavigationLink {
                        LiveWorkoutView()
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    AppCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today").font(.headline)
                                Text("\(history.sessions.count) workouts • \(history.sessions.first?.totalReps ?? 0) reps")
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Spacer()
                            Image(systemName: "flame.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .appBackground()
        }
    }
}

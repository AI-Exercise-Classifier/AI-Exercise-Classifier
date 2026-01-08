//
//  WorkoutHistoryView.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI

struct WorkoutHistoryView: View {
    @StateObject private var history = WorkoutHistoryStore.shared

    var body: some View {
        List {
            if history.sessions.isEmpty {
                Section {
                    Text("No workouts yet.")
                        .foregroundStyle(AppTheme.subtext)
                }
            } else {
                Section("Workouts") {
                    ForEach(history.sessions) { s in
                        NavigationLink {
                            WorkoutSummaryView(session: s)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)

                                Text("\(s.sets.count) sets • \(s.totalReps) reps • Vol \(Int(s.totalVolume))")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onDelete(perform: history.deleteSessions)
                }

                Section {
                    Button(role: .destructive) {
                        history.clearAll()
                    } label: {
                        Label("Delete all history", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
//
//  WorkoutSummary.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//


import Foundation

struct WorkoutSummary: Codable {
    let date: Date
    let duration: TimeInterval
    let repsByExercise: [ExerciseType: Int]
}

//
//  ExerciseType.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//

import Foundation

enum ExerciseType: String, CaseIterable, Codable, Hashable {
    /// No meaningful movement (standing still / resting). Important so the model doesn't always guess an exercise.
    case idle
    case squat
    case pushUp
    case curl

    /// New exercises
    case benchPress
    case pullUp
    case cableRow

    /// Generic walking movement (useful negative/other class when phone is worn on the arm).
    case walking
    case unknown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .squat: return "Squat"
        case .pushUp: return "Push-up"
        case .curl: return "Bicep curl"
        case .benchPress: return "Bench press"
        case .pullUp: return "Pull-ups"
        case .cableRow: return "Cable rows"
        case .walking: return "Walking"
        case .unknown: return "Unknown"
        }
    }

    /// Use this to populate pickers for data collection.
    /// We exclude `.unknown` because it isn't a meaningful training label.
    static var recordableCases: [ExerciseType] {
        allCases.filter { $0 != .unknown }
    }
}

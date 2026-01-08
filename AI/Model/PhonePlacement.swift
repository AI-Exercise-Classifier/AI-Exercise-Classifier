//
//  PhonePlacement.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//


import Foundation

enum PhonePlacement: String, CaseIterable, Codable, Hashable {
    case upperArm
    case forearm

    var displayName: String {
        switch self {
        case .upperArm: return "Upper arm"
        case .forearm: return "Forearm"
        }
    }
}

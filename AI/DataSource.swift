//
//  DataSource.swift
//  AI
//
//  Created by Romeo Haddad on 2025-12-20.
//


import Foundation

enum DataSource: String, CaseIterable, Codable, Hashable {
    case phone
    case watch

    var displayName: String {
        switch self {
        case .phone: return "Phone"
        case .watch: return "Watch"
        }
    }
}
//
//  AppTheme.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI

enum AppTheme {
    
    static let corner: CGFloat = 22
    
    static let bg = Color(.systemBackground)
    static let card = Color(.secondarySystemBackground)
    static let text = Color.primary
    static let subtext = Color.secondary
    static let accent = Color.blue
    static let accent2 = Color.purple

    static let gradient = LinearGradient(colors: [accent, accent2],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing)
}
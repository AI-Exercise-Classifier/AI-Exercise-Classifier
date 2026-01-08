//
//  PrimaryButtonStyle.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
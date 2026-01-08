//
//  AppBackground.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                AppTheme.bg
                    .overlay(
                        AppTheme.gradient.opacity(0.12)
                            .blur(radius: 50)
                    )
                    .ignoresSafeArea()
            )
            .foregroundStyle(AppTheme.text)
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}

struct AppCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.card.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous))
            .shadow(radius: 12, y: 6)
    }
}

//
//  StatPill.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI

struct StatPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(AppTheme.subtext)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
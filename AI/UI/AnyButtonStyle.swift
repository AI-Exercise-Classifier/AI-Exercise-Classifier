//
//  AnyButtonStyle.swift
//  AI
//
//  Created by Romeo Haddad on 2026-01-07.
//


import SwiftUI
import Combine
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>( style: S) {
        _makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

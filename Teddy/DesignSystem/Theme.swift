//
//  Theme.swift
//  Teddy
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let accent = Color(hex: 0xFF2D78)

    /// Tracks the system grouped background so the fade works in light and dark.
    static var background: Color { Color(.systemGroupedBackground) }

    /// Top-of-screen tint fading into the background, as on the Race Pace detail screens.
    static func screenGradient(_ top: Color = accent) -> LinearGradient {
        LinearGradient(
            colors: [top.opacity(0.35), background],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.4)
        )
    }
}

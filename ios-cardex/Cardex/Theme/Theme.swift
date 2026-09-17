import SwiftUI

/// Central design tokens for Cardex: a sleek graphite shell with a single indigo accent.
enum Theme {
    // Surfaces
    static let canvas = Color(hex: 0x0D0D0F)
    static let surface = Color(hex: 0x17181B)
    static let surfaceHigh = Color(hex: 0x202127)
    static let hairline = Color(hex: 0x2A2B31)

    // Text
    static let textPrimary = Color(hex: 0xF2F1EE)
    static let textSecondary = Color(hex: 0x8A8A90)
    static let textTertiary = Color(hex: 0x5B5C63)

    // Accent
    static let accent = Color(hex: 0x6C7BFF)
    static let accentSoft = Color(hex: 0x6C7BFF, opacity: 0.16)
    static let openDoor = Color(hex: 0x7BAE96)
    static let warning = Color(hex: 0xC9A227)

    // Geometry
    static let cardRadius: CGFloat = 26
    static let tileRadius: CGFloat = 18
    static let rowRadius: CGFloat = 16
    static let margin: CGFloat = 20

    // Motion
    static let snappy = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.88)
}

extension View {
    /// Standard elevated container used for tiles, rows and grouped lists.
    func panel(radius: CGFloat = Theme.tileRadius) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
    }
}

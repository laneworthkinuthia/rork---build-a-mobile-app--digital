import SwiftUI

/// Muted duotone finishes applied to business cards. Each person keeps one finish
/// so their card is recognisable in the rolodex without the UI becoming noisy.
enum CardPalette: String, CaseIterable, Identifiable, Codable {
    case slate
    case sand
    case sage
    case indigo
    case clay
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slate: "Slate"
        case .sand: "Sand"
        case .sage: "Sage"
        case .indigo: "Indigo"
        case .clay: "Clay"
        case .graphite: "Graphite"
        }
    }

    var top: Color {
        switch self {
        case .slate: Color(hex: 0x3C444E)
        case .sand: Color(hex: 0x6B5A46)
        case .sage: Color(hex: 0x3F4B43)
        case .indigo: Color(hex: 0x3A3E5E)
        case .clay: Color(hex: 0x5D4340)
        case .graphite: Color(hex: 0x33343A)
        }
    }

    var bottom: Color {
        switch self {
        case .slate: Color(hex: 0x14171B)
        case .sand: Color(hex: 0x231D18)
        case .sage: Color(hex: 0x161A18)
        case .indigo: Color(hex: 0x15161F)
        case .clay: Color(hex: 0x201917)
        case .graphite: Color(hex: 0x121316)
        }
    }

    var base: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    /// Scrim laid over the photo so card typography always stays legible.
    var scrim: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bottom.opacity(0.96), location: 0),
                .init(color: bottom.opacity(0.72), location: 0.42),
                .init(color: top.opacity(0.18), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var vignette: LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear, .black.opacity(0.35)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

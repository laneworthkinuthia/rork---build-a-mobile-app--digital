import SwiftUI

/// The four visibility modes that govern how discoverable a member is.
enum VisibilityMode: String, CaseIterable, Identifiable, Codable {
    case live
    case publicMode = "public"
    case privateMode = "private"
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "Live"
        case .publicMode: "Public"
        case .privateMode: "Private"
        case .dark: "Dark"
        }
    }

    var caption: String {
        switch self {
        case .live: "Your card is visible to people in your room"
        case .publicMode: "Visible to your connections and approved people"
        case .privateMode: "Discoverable, but contact details stay locked"
        case .dark: "Invisible. Exchange cards manually only"
        }
    }

    var symbol: String {
        switch self {
        case .live: "dot.radiowaves.left.and.right"
        case .publicMode: "person.2"
        case .privateMode: "lock"
        case .dark: "moon"
        }
    }

    var tint: Color {
        switch self {
        case .live: Theme.accent
        case .publicMode: Theme.openDoor
        case .privateMode: Theme.warning
        case .dark: Theme.textSecondary
        }
    }

    /// Whether the member appears in room discovery for other people.
    var isDiscoverable: Bool { self != .dark }

    /// The highest tier of card access this mode allows the member to grant.
    /// Requests can only ever be approved up to this ceiling.
    var maxShareableTier: AccessTier {
        switch self {
        case .live, .publicMode: .trusted
        case .privateMode: .connected
        case .dark: .publicTier
        }
    }
}

import Foundation

/// A lightweight professional update. The activity layer, secondary to the card.
nonisolated struct FeedPost: Identifiable, Hashable, Codable {
    enum Audience: String, CaseIterable, Identifiable, Codable {
        case everyone
        case connections
        case room
        case privateOnly = "private"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .everyone: "Everyone"
            case .connections: "Connections"
            case .room: "Room"
            case .privateOnly: "Private"
            }
        }

        var symbol: String {
            switch self {
            case .everyone: "globe"
            case .connections: "person.2.fill"
            case .room: "door.left.hand.open"
            case .privateOnly: "lock.fill"
            }
        }
    }

    let id: UUID
    var author: BusinessCard
    var body: String
    var imageName: String?
    var postedAt: Date
    var audience: Audience
    var applauds: Int
    var comments: Int
    var hasApplauded: Bool

    init(
        id: UUID = UUID(),
        author: BusinessCard,
        body: String,
        imageName: String? = nil,
        postedAt: Date,
        audience: Audience = .connections,
        applauds: Int = 0,
        comments: Int = 0,
        hasApplauded: Bool = false
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.imageName = imageName
        self.postedAt = postedAt
        self.audience = audience
        self.applauds = applauds
        self.comments = comments
        self.hasApplauded = hasApplauded
    }
}

nonisolated extension Date {
    /// Compact relative label such as "12m ago" used across activity surfaces.
    var shortRelativeLabel: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
}

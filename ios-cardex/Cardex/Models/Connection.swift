import Foundation

/// A card the user has collected into their rolodex.
nonisolated struct Connection: Identifiable, Hashable, Codable {
    enum Origin: String, Codable, Hashable {
        case exchange
        case request
        case room

        var verb: String {
            switch self {
            case .exchange: "Exchanged"
            case .request: "Connected"
            case .room: "Met"
            }
        }
    }

    let id: UUID
    var card: BusinessCard
    var metAt: String
    var metOn: Date
    var origin: Origin
    var isFavorite: Bool
    var note: String
    /// The tier of information this person has granted the user.
    var grantedTier: AccessTier
    var accessRequestPending: Bool

    init(
        id: UUID = UUID(),
        card: BusinessCard,
        metAt: String,
        metOn: Date,
        origin: Origin = .exchange,
        isFavorite: Bool = false,
        note: String = "",
        grantedTier: AccessTier = .connected,
        accessRequestPending: Bool = false
    ) {
        self.id = id
        self.card = card
        self.metAt = metAt
        self.metOn = metOn
        self.origin = origin
        self.isFavorite = isFavorite
        self.note = note
        self.grantedTier = grantedTier
        self.accessRequestPending = accessRequestPending
    }

    var metLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Met at \(metAt) — \(formatter.string(from: metOn))"
    }

    /// Details visible to the user given the tier the owner granted.
    var visibleDetails: [ContactDetail] {
        card.details.filter { $0.tier.rank <= grantedTier.rank }
    }

    var lockedDetails: [ContactDetail] {
        card.details.filter { $0.tier.rank > grantedTier.rank }
    }
}

/// Someone asking to see more of the user's card, or the user asking to see more of theirs.
nonisolated struct AccessRequest: Identifiable, Hashable, Codable {
    enum Direction: String, Codable, Hashable {
        case incoming
        case outgoing
    }

    enum Status: String, Codable, Hashable {
        case pending
        case approved
        case declined
    }

    let id: UUID
    var card: BusinessCard
    var direction: Direction
    var requestedTier: AccessTier
    var status: Status
    var createdAt: Date
    var context: String

    init(
        id: UUID = UUID(),
        card: BusinessCard,
        direction: Direction,
        requestedTier: AccessTier = .trusted,
        status: Status = .pending,
        createdAt: Date,
        context: String
    ) {
        self.id = id
        self.card = card
        self.direction = direction
        self.requestedTier = requestedTier
        self.status = status
        self.createdAt = createdAt
        self.context = context
    }
}

/// An entry in the Cards home activity list.
nonisolated struct ActivityItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case accepted
        case exchanged
        case accessRequest
        case requestSent
        case joinedRoom
        case ticketPurchased
        case eventCreated
    }

    let id: UUID
    let card: BusinessCard
    let kind: Kind
    let detail: String
    let date: Date

    init(id: UUID = UUID(), card: BusinessCard, kind: Kind, detail: String, date: Date) {
        self.id = id
        self.card = card
        self.kind = kind
        self.detail = detail
        self.date = date
    }

    var headline: String {
        switch kind {
        case .accepted: "\(card.name) accepted your request"
        case .exchanged: "Exchanged with \(card.name)"
        case .accessRequest: "\(card.name) requested private access"
        case .requestSent: "You requested \(card.firstName)'s card"
        case .joinedRoom: "\(card.name) joined your room"
        case .ticketPurchased: "Ticket purchased for \(detail)"
        case .eventCreated: "You created \(detail)"
        }
    }

    var symbol: String {
        switch kind {
        case .accepted: "checkmark.seal.fill"
        case .exchanged: "arrow.left.arrow.right"
        case .accessRequest: "lock.open.fill"
        case .requestSent: "paperplane.fill"
        case .joinedRoom: "door.left.hand.open"
        case .ticketPurchased: "ticket.fill"
        case .eventCreated: "plus.rectangle.on.folder.fill"
        }
    }
}

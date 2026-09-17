import Foundation

/// A physical networking environment that members can be live inside.
nonisolated struct Room: Identifiable, Hashable, Codable {
    enum Access: String, Codable, Hashable {
        case openDoor
        case request
        case ticketed

        var badge: String {
            switch self {
            case .openDoor: "Open door"
            case .request: "Request to join"
            case .ticketed: "Ticketed"
            }
        }

        var actionTitle: String {
            switch self {
            case .openDoor: "Enter"
            case .request: "Request"
            case .ticketed: "Buy ticket"
            }
        }

        var symbol: String {
            switch self {
            case .openDoor: "door.left.hand.open"
            case .request: "lock.fill"
            case .ticketed: "ticket.fill"
            }
        }
    }

    enum Membership: String, Codable, Hashable {
        case none
        case pending
        case joined
    }

    let id: UUID
    var name: String
    var venue: String
    var city: String
    var blurb: String
    var imageName: String
    var distanceMiles: Double
    var liveCount: Int
    var access: Access
    var membership: Membership
    var attendeeIDs: [UUID]
    /// The person hosting this event, if any.
    var hostID: UUID?
    /// Ticket price in pounds. `nil` means entry is free.
    var ticketPrice: Double?
    /// People whose entry requests the host has yet to approve.
    var pendingAttendeeIDs: [UUID]
    /// Whether the host is broadcasting the event live right now.
    var isBroadcasting: Bool

    init(
        id: UUID = UUID(),
        name: String,
        venue: String,
        city: String,
        blurb: String,
        imageName: String,
        distanceMiles: Double,
        liveCount: Int,
        access: Access,
        membership: Membership = .none,
        attendeeIDs: [UUID] = [],
        hostID: UUID? = nil,
        ticketPrice: Double? = nil,
        pendingAttendeeIDs: [UUID] = [],
        isBroadcasting: Bool = false
    ) {
        self.id = id
        self.name = name
        self.venue = venue
        self.city = city
        self.blurb = blurb
        self.imageName = imageName
        self.distanceMiles = distanceMiles
        self.liveCount = liveCount
        self.access = access
        self.membership = membership
        self.attendeeIDs = attendeeIDs
        self.hostID = hostID
        self.ticketPrice = ticketPrice
        self.pendingAttendeeIDs = pendingAttendeeIDs
        self.isBroadcasting = isBroadcasting
    }

    var distanceLabel: String { String(format: "%.1fmi", distanceMiles) }

    var isFree: Bool { ticketPrice == nil || ticketPrice == 0 }

    var priceLabel: String {
        guard let ticketPrice, ticketPrice > 0 else { return "Free" }
        return String(format: "£%.0f", ticketPrice)
    }
}

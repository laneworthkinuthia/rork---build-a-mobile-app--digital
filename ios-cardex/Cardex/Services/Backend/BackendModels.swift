import Foundation

/// Wire types for the Cardex beta backend. Field names intentionally match
/// the Codable models (BusinessCard, Connection, AccessRequest, Room, Message,
/// FeedPost) so the snapshot decodes directly into existing app models —
/// the server is the authority and already applies tier filtering.

struct BackendSnapshot: Decodable {
    let me: BusinessCard?
    let connections: [Connection]
    let requests: [AccessRequest]
    let rooms: [Room]
    let messages: [Message]
    let posts: [FeedPost]
    let discoverable: [BusinessCard]
    let activity: [BackendActivity]
    let blocked: [BlockedUser]
    let readMarkers: [String: Double]
    let serverTime: Double
}

/// A person the user has blocked. The server keeps the relationship torn down;
/// the client only needs the name for the settings list.
struct BlockedUser: Decodable, Identifiable {
    let id: UUID
    let name: String
}

/// Activity arrives as a wire type because `ActivityItem.Kind` is not Codable.
struct BackendActivity: Decodable {
    let id: UUID
    let card: BusinessCard
    let kind: String
    let detail: String
    let date: Double

    var activityItem: ActivityItem? {
        let kind: ActivityItem.Kind
        switch self.kind {
        case "accepted": kind = .accepted
        case "exchanged": kind = .exchanged
        case "accessRequest": kind = .accessRequest
        case "requestSent": kind = .requestSent
        case "joinedRoom": kind = .joinedRoom
        case "ticketPurchased": kind = .ticketPurchased
        case "eventCreated": kind = .eventCreated
        case "cardCreated": kind = .cardCreated
        case "roomJoined": kind = .roomJoined
        default: return nil
        }
        return ActivityItem(
            id: id,
            card: card,
            kind: kind,
            detail: detail,
            date: Date(timeIntervalSince1970: date),
        )
    }
}

struct ExchangePreview: Decodable {
    let card: BusinessCard
    let userUUID: String
}

struct CreateRoomResponse: Decodable {
    let ok: Bool
    let roomID: String
}

// MARK: - Beta message store

/// The backend is the source of truth for messages; this repository holds the
/// current snapshot plus live pushes for the UI. Never persisted locally.
@MainActor
final class InMemoryMessageRepository: MessageRepository {
    private(set) var messages: [Message] = []

    func replace(_ all: [Message]) {
        messages = all
    }

    /// Appends without duplicating — optimistic sends and the server echo
    /// share an id.
    func append(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    func add(_ message: Message) {
        append(message)
    }

    func removeMessages(with participantID: UUID) {
        messages.removeAll { $0.senderID == participantID || $0.recipientID == participantID }
    }

    func remove(id: UUID) {
        messages.removeAll { $0.id == id }
    }
}

struct SentMessageResponse: Decodable {
    let ok: Bool
    let message: Message
}

// MARK: - Realtime events

/// Events pushed over the WebSocket. Anything we can't apply surgically falls
/// back to a snapshot refresh, which is deliberately simple and reliable.
enum RealtimeEvent {
    case messageNew(Message)
    case needsRefresh

    static func parse(_ data: Data) -> RealtimeEvent? {
        struct Envelope: Decodable {
            let type: String
            let message: Message?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        switch envelope.type {
        case "message.new":
            if let message = envelope.message { return .messageNew(message) }
            return .needsRefresh
        case "pong":
            return nil
        default:
            // request.new, request.resolved, connection.new, room.updated,
            // feed.new, state.refresh, peer.updated
            return .needsRefresh
        }
    }
}

// MARK: - Transport coding for the owner card

enum TransportCoding {
    /// Encodes the owner's card for the backend. The app's normal encoder
    /// stores photo blobs on disk and writes file references; the backend needs
    /// the bytes inline (base64), so encoding runs against a null media store.
    /// Sizes are capped server-side.
    static func cardData(_ card: BusinessCard, encoder: JSONEncoder) throws -> Data {
        let cardStore = BusinessCard.mediaStore
        let storyStore = StoryUpdate.mediaStore
        BusinessCard.mediaStore = NullMediaStore()
        StoryUpdate.mediaStore = NullMediaStore()
        defer {
            BusinessCard.mediaStore = cardStore
            StoryUpdate.mediaStore = storyStore
        }
        return try encoder.encode(card)
    }
}

/// Media store that never persists — used only to inline blobs for transport.
nonisolated final class NullMediaStore: MediaStoring {
    func store(_ data: Data, forKey key: String) -> String? { nil }
    func loadData(forReference reference: String) -> Data? { nil }
}

import Testing
import Foundation
@testable import Cardex

// MARK: - Helpers

/// Builds an isolated store: fresh UserDefaults suite, instant simulated
/// payments, and a message repository namespaced by a fresh owner id.
@MainActor
private func makeStore(paymentDelay: Duration = .zero) -> CardexStore {
    let defaults = UserDefaults(suiteName: "cardex-tests-\(UUID().uuidString)")
    let processor = SimulatedPaymentProcessor()
    processor.simulatedDelay = paymentDelay
    return CardexStore(defaults: defaults ?? .standard, paymentProcessor: processor)
}

// MARK: - Access tiers & privacy ceilings

@MainActor
struct AccessTierTests {

    @Test func tierOrdering() {
        #expect(AccessTier.publicTier.rank < AccessTier.connected.rank)
        #expect(AccessTier.connected.rank < AccessTier.trusted.rank)
    }

    @Test func clampedByCeiling() {
        #expect(AccessTier.trusted.clamped(by: .publicTier) == .publicTier)
        #expect(AccessTier.trusted.clamped(by: .connected) == .connected)
        #expect(AccessTier.connected.clamped(by: .trusted) == .connected)
        #expect(AccessTier.publicTier.clamped(by: .trusted) == .publicTier)
    }

    @Test func maxShareableTierFollowsVisibilityMode() {
        #expect(VisibilityMode.live.maxShareableTier == .trusted)
        #expect(VisibilityMode.publicMode.maxShareableTier == .trusted)
        #expect(VisibilityMode.privateMode.maxShareableTier == .connected)
        #expect(VisibilityMode.dark.maxShareableTier == .publicTier)
    }
}

// MARK: - Connection requests & approvals

@MainActor
struct ConnectionRequestTests {

    @Test func outgoingCardRequestIsNotDuplicated() {
        let store = makeStore()
        let candidate = store.discoverable[0]

        store.requestCardAccess(to: candidate)
        store.requestCardAccess(to: candidate)
        store.requestCardAccess(to: candidate)

        let pending = store.requests.filter {
            $0.card.id == candidate.id && $0.direction == .outgoing && $0.status == .pending
        }
        #expect(pending.count == 1)
    }

    @Test func accessRequestCannotBeStacked() {
        let store = makeStore()
        guard let connection = store.connections.first else {
            Issue.record("Seed data missing connections")
            return
        }

        store.requestAccess(from: connection.id)
        store.requestAccess(from: connection.id)

        let pending = store.requests.filter {
            $0.card.id == connection.card.id && $0.direction == .outgoing && $0.status == .pending
        }
        #expect(pending.count == 1)
    }

    @Test func approvingIncomingRequestCreatesClampedConnection() {
        let store = makeStore()
        guard let incoming = store.incomingRequests.first else {
            Issue.record("Seed data missing an incoming request")
            return
        }
        let expectedTier = incoming.requestedTier.clamped(by: store.owner.visibility.maxShareableTier)

        store.resolveRequest(incoming.id, approve: true)

        let connection = store.connection(for: incoming.card.id)
        #expect(connection != nil)
        #expect(connection?.grantedTier == expectedTier)
    }

    @Test func decliningIncomingRequestDoesNotCreateConnection() {
        let store = makeStore()
        guard let incoming = store.incomingRequests.first else {
            Issue.record("Seed data missing an incoming request")
            return
        }
        let cardID = incoming.card.id

        store.resolveRequest(incoming.id, approve: false)

        #expect(store.connection(for: cardID) == nil)
        #expect(!store.isConnected(incoming.card))
    }

    @Test func grantTierIsClampedByConnectionCeiling() {
        let store = makeStore()
        guard let connection = store.connections.first else {
            Issue.record("Seed data missing connections")
            return
        }
        let ceiling = connection.card.visibility.maxShareableTier

        store.grantTier(.trusted, to: connection.id)

        let updated = store.connections.first { $0.id == connection.id }
        #expect(updated?.grantedTier == AccessTier.trusted.clamped(by: ceiling))
    }

    @Test func exchangeCardsGrantsNoMoreThanTheCeiling() {
        let store = makeStore()
        let candidate = store.discoverable[0]

        let connection = store.exchangeCards(with: candidate, at: "Test Mixer")

        #expect(connection.grantedTier == AccessTier.connected.clamped(by: candidate.visibility.maxShareableTier))
    }
}

// MARK: - Relationship teardown

@MainActor
struct RelationshipTests {

    @Test func removeConnectionTearsDownAllState() {
        let store = makeStore()
        guard let connection = store.connections.first else {
            Issue.record("Seed data missing connections")
            return
        }
        let cardID = connection.card.id

        store.sendMessage("See you at the demo night", to: cardID)
        store.markThreadRead(cardID)
        store.requestConnection(with: connection.card)
        #expect(!store.messages(with: cardID).isEmpty)

        store.removeConnection(connection.id)

        #expect(store.connection(for: cardID) == nil)
        #expect(store.messages(with: cardID).isEmpty)
        #expect(!store.requests.contains { $0.card.id == cardID })
        #expect(!store.pendingConnectionIDs.contains(cardID))
        #expect(store.discoverable.contains { $0.id == cardID })
    }
}

// MARK: - Rooms & ticketed events

@MainActor
struct RoomTests {

    @Test func enteringOpenDoorRoomJoinsInstantly() {
        let store = makeStore()
        guard let room = store.rooms.first(where: { $0.access == .openDoor && $0.membership != .joined }) else {
            Issue.record("Seed data missing a non-joined open-door room")
            return
        }

        store.enterRoom(room.id)

        #expect(store.rooms.first { $0.id == room.id }?.membership == .joined)
    }

    @Test func onlyOneRoomCanBeJoinedAtATime() throws {
        let store = makeStore()
        let first = try #require(store.rooms.first { $0.access == .openDoor && $0.membership != .joined })
        let second = try #require(store.rooms.first { $0.access == .openDoor && $0.id != first.id })

        store.enterRoom(first.id)
        store.enterRoom(second.id)

        // Bare `.none` would compare against Optional.none (nil) — compare
        // against the explicit enum case.
        #expect(store.rooms.first { $0.id == first.id }?.membership == Room.Membership.none)
        #expect(store.rooms.first { $0.id == second.id }?.membership == .joined)
        #expect(store.currentRoom?.id == second.id)
    }

    @Test func leavingRoomResetsMembership() throws {
        let store = makeStore()
        let room = try #require(store.rooms.first { $0.access == .openDoor && $0.membership != .joined })

        store.enterRoom(room.id)
        store.leaveRoom(room.id)

        #expect(store.rooms.first { $0.id == room.id }?.membership == Room.Membership.none)
        #expect(store.currentRoom == nil)
    }

    @Test func ticketedRoomBlocksEntryUntilPurchased() async throws {
        let store = makeStore()
        let ticketed = try #require(store.rooms.first { $0.access == .ticketed })

        store.enterRoom(ticketed.id)
        #expect(store.rooms.first { $0.id == ticketed.id }?.membership != .joined)

        try await store.purchaseTicket(ticketed.id)
        #expect(store.rooms.first { $0.id == ticketed.id }?.membership == .joined)
    }

    @Test func purchaseTicketIsIgnoredForNonTicketedRooms() async throws {
        let store = makeStore()
        let open = try #require(store.rooms.first { $0.access == .openDoor && $0.membership != .joined })

        try await store.purchaseTicket(open.id)

        #expect(store.rooms.first { $0.id == open.id }?.membership != .joined)
    }

    @Test func roomsAttendedReportsRealCount() throws {
        let store = makeStore()
        let room = try #require(store.rooms.first { $0.access == .openDoor && $0.membership != .joined })

        let before = store.rooms.filter { $0.membership == .joined }.count
        #expect(store.roomsAttended == before)

        // Entering a room leaves the previously joined one (single joined
        // room), so the count reflects exactly one currently joined room.
        store.enterRoom(room.id)
        #expect(store.roomsAttended == 1)
        #expect(store.currentRoom?.id == room.id)
    }
}

// MARK: - Messaging

@MainActor
struct MessagingTests {

    @Test func sendMessageAppendsToThread() throws {
        let store = makeStore()
        let partner = try #require(store.connections.first?.card)
        let before = store.messages(with: partner.id).count

        store.sendMessage("Hello from the tests", to: partner.id)

        let thread = store.messages(with: partner.id)
        #expect(thread.count == before + 1)
        #expect(thread.last?.text == "Hello from the tests")
        #expect(thread.last?.senderID == store.owner.id)
    }

    @Test func sendMessageToUnknownCardIsIgnored() {
        let store = makeStore()
        let stranger = UUID()

        store.sendMessage("Anyone there?", to: stranger)

        #expect(store.messages(with: stranger).isEmpty)
    }

    @Test func simulatedReplyComesFromThePartner() {
        let store = makeStore()
        let partnerID = UUID()
        let repository = LocalMessageRepository(ownerID: store.owner.id)

        let reply = repository.makeSimulatedReply(from: partnerID)

        #expect(reply.senderID == partnerID)
        #expect(reply.recipientID == store.owner.id)
        #expect(!reply.text.isEmpty)
    }
}

// MARK: - Story expiration

@MainActor
struct StoryExpirationTests {

    @Test func freshStoryIsActive() {
        let story = StoryUpdate(imageName: "rooftop_gathering_dusk", caption: "Now", postedAt: Date())

        #expect(story.isActive)
    }

    @Test func storyExpiresAfter24Hours() {
        let expired = StoryUpdate(
            imageName: "rooftop_gathering_dusk",
            caption: "Yesterday",
            postedAt: Date().addingTimeInterval(-25 * 3600)
        )
        let almostGone = StoryUpdate(
            imageName: "rooftop_gathering_dusk",
            caption: "Almost",
            postedAt: Date().addingTimeInterval(-23 * 3600)
        )

        #expect(!expired.isActive)
        #expect(almostGone.isActive)
    }
}

// MARK: - Persistence & media boundaries

@MainActor
struct PersistenceTests {

    @Test func photoBlobIsStoredOnDiskNotInPayload() throws {
        let blob = Data("fake-jpeg-bytes-for-testing".utf8)
        var card = SampleData.makeOwner()
        card.photoData = blob

        let data = try JSONEncoder().encode(card)
        let payload = String(decoding: data, as: UTF8.self)
        #expect(!payload.contains("fake-jpeg-bytes-for-testing"), "Photo blob leaked into the JSON payload")

        let decoded = try JSONDecoder().decode(BusinessCard.self, from: data)
        #expect(decoded.photoData == blob)
    }

    @Test func legacyInlinePhotoPayloadStillDecodes() throws {
        var card = SampleData.makeOwner()
        let blob = Data("legacy-blob".utf8)
        card.photoData = blob

        // Hand-build the legacy payload that inlined the base64 blob.
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(card)) as? [String: Any]
        )
        object.removeValue(forKey: "photoReference")
        object["photoData"] = blob.base64EncodedString()
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(BusinessCard.self, from: legacy)
        #expect(decoded.photoData == blob)
    }

    @Test func messageRoundTrip() throws {
        let message = Message(senderID: UUID(), recipientID: UUID(), text: "Round trip")
        let data = try JSONEncoder().encode([message])
        let decoded = try JSONDecoder().decode([Message].self, from: data)
        #expect(decoded.first?.text == "Round trip")
        #expect(decoded.first?.sentAt.timeIntervalSince1970 == message.sentAt.timeIntervalSince1970)
    }
}

// MARK: - Search & filtering

@MainActor
struct SearchTests {

    @Test func connectionSearchMatchesAndFilters() throws {
        let store = makeStore()
        let known = try #require(store.connections.first?.card.name)

        #expect(!store.filteredConnections(query: known).isEmpty)
        #expect(store.filteredConnections(query: "zzz-not-a-person").isEmpty)
        #expect(store.filteredConnections(query: "").count == store.connections.count)
    }

    @Test func peopleSearchNeedsAQuery() {
        let store = makeStore()

        #expect(store.searchPeople(query: "").isEmpty)
        #expect(!store.searchPeople(query: store.connections[0].card.name).isEmpty)
    }

    @Test func roomSearchMatchesNamesAndVenues() throws {
        let store = makeStore()
        let room = try #require(store.rooms.first)

        #expect(store.searchRooms(query: room.name).contains { $0.id == room.id })
        #expect(!store.searchRooms(query: "zzz-not-a-room").isEmpty == false)
    }
}

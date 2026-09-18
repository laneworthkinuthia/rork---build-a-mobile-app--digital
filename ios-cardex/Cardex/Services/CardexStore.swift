import Foundation
import Observation
import os

/// Single source of truth for the prototype: the owner's card, their rolodex,
/// rooms, access requests and the feed.
@MainActor
@Observable
final class CardexStore {
    enum RolodexSort: String, CaseIterable, Identifiable {
        case recent
        case name
        case company

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: "Recent"
            case .name: "Name"
            case .company: "Company"
            }
        }
    }

    private(set) var owner: BusinessCard
    private(set) var connections: [Connection]
    private(set) var rooms: [Room]
    private(set) var requests: [AccessRequest]
    private(set) var posts: [FeedPost]
    private(set) var activity: [ActivityItem]
    /// Message storage lives behind a repository so a backend can replace the
    /// local development implementation without UI changes.
    let messageRepository: any MessageRepository
    /// Payment processing. Only the simulated processor exists today — it is
    /// NOT a real payment provider (see PRODUCTION_READINESS.md).
    let paymentProcessor: any PaymentProcessing
    /// Last time each thread was opened; incoming messages after this are unread.
    private(set) var readMarkers: [UUID: Date] = [:]
    /// Tracked simulated-reply tasks so they can be cancelled and never
    /// resurrect state for a removed relationship.
    private var replyTasks: [UUID: Task<Void, Never>] = [:]
    /// People discoverable in rooms who are not yet in the rolodex.
    private(set) var discoverable: [BusinessCard]
    private(set) var pendingConnectionIDs: Set<UUID> = []
    /// Rooms the user is attending remotely rather than in person.
    private(set) var remoteRoomIDs: Set<UUID> = []

    var rolodexSort: RolodexSort = .recent
    var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults
    private let onboardingKey = "cardex.onboarded"
    private let ownerKey = "cardex.owner"
    private let readMarkersKey = "cardex.readMarkers"

    /// - Parameters:
    ///   - defaults: Injected so tests and previews can isolate persistence.
    ///   - messageRepository: Defaults to the local development repository.
    ///   - paymentProcessor: Defaults to the simulated processor (no real charge).
    init(
        defaults: UserDefaults = .standard,
        messageRepository: (any MessageRepository)? = nil,
        paymentProcessor: (any PaymentProcessing)? = nil
    ) {
        self.defaults = defaults

        // UI-test hooks: start from a clean slate, optionally skipping onboarding.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("UITEST_RESET") {
            defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "Cardex")
        }

        let loadedOwner: BusinessCard
        if let data = defaults.data(forKey: ownerKey),
           let stored = try? JSONDecoder().decode(BusinessCard.self, from: data) {
            loadedOwner = stored
        } else {
            loadedOwner = SampleData.makeOwner()
        }
        owner = loadedOwner
        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        if arguments.contains("UITEST_SKIP_ONBOARDING") {
            hasCompletedOnboarding = true
            defaults.set(true, forKey: onboardingKey)
        }

        if let data = defaults.data(forKey: readMarkersKey),
           let stored = try? JSONDecoder().decode([UUID: Date].self, from: data) {
            readMarkers = stored
        }

        self.messageRepository = messageRepository ?? LocalMessageRepository(ownerID: loadedOwner.id)
        self.paymentProcessor = paymentProcessor ?? SimulatedPaymentProcessor()

        let contacts = SampleData.makeContacts()

        let sarah = contacts[0]
        let daniel = contacts[1]
        let james = contacts[2]
        let elena = contacts[3]
        let marcus = contacts[4]
        let priya = contacts[5]
        let tom = contacts[6]

        connections = [
            Connection(
                card: sarah,
                metAt: "London Tech Week",
                metOn: Self.date(year: 2026, month: 6, day: 11),
                origin: .exchange,
                isFavorite: true,
                note: "Wants to collaborate on the Nova rebrand.",
                grantedTier: .trusted
            ),
            Connection(
                card: daniel,
                metAt: "TechWeek Mixer",
                metOn: Self.date(year: 2026, month: 9, day: 15),
                origin: .exchange,
                note: "Deep on offline-first sync.",
                grantedTier: .connected
            ),
            Connection(
                card: james,
                metAt: "Harbourline Demo Night",
                metOn: Self.date(year: 2026, month: 8, day: 28),
                origin: .request,
                grantedTier: .publicTier
            ),
            Connection(
                card: tom,
                metAt: "Dublin Data Summit",
                metOn: Self.date(year: 2026, month: 5, day: 2),
                origin: .room,
                note: "Intro to their analytics team in Q4.",
                grantedTier: .connected
            )
        ]

        discoverable = [elena, marcus]
        rooms = SampleData.makeRooms(attendeeIDs: [elena.id, marcus.id, priya.id, tom.id, daniel.id])

        requests = [
            AccessRequest(
                card: elena,
                direction: .incoming,
                requestedTier: .trusted,
                createdAt: Date().addingTimeInterval(-5 * 3600),
                context: "Founders Breakfast"
            ),
            AccessRequest(
                card: priya,
                direction: .outgoing,
                requestedTier: .connected,
                createdAt: Date().addingTimeInterval(-26 * 3600),
                context: "TechWeek Mixer"
            )
        ]

        posts = [
            FeedPost(
                author: sarah,
                body: "Wrapped the Studio OK identity refresh today. Six months of work, one very small logo.",
                imageName: "design_studio_meetup",
                postedAt: Date().addingTimeInterval(-2 * 3600),
                audience: .everyone,
                applauds: 84,
                comments: 12
            ),
            FeedPost(
                author: marcus,
                body: "Loop just crossed 10,000 weekly active teams. Hiring two product engineers in London.",
                postedAt: Date().addingTimeInterval(-7 * 3600),
                audience: .connections,
                applauds: 146,
                comments: 31
            ),
            FeedPost(
                author: elena,
                body: "Running a growth teardown at Founders Breakfast on Thursday. Bring a landing page, leave with a list.",
                imageName: "founders_breakfast_cafe",
                postedAt: Date().addingTimeInterval(-19 * 3600),
                audience: .room,
                applauds: 52,
                comments: 9
            ),
            FeedPost(
                author: tom,
                body: "Published our notes on keeping query latency under 50ms while tripling event volume.",
                postedAt: Date().addingTimeInterval(-2 * 86_400),
                audience: .everyone,
                applauds: 210,
                comments: 24
            )
        ]

        activity = [
            ActivityItem(card: sarah, kind: .accepted, detail: "accepted your request", date: Date().addingTimeInterval(-12 * 60)),
            ActivityItem(card: daniel, kind: .exchanged, detail: "TechWeek Mixer", date: Date().addingTimeInterval(-2 * 3600)),
            ActivityItem(card: james, kind: .accessRequest, detail: "requested private access", date: Date().addingTimeInterval(-5 * 3600)),
            ActivityItem(card: elena, kind: .joinedRoom, detail: "TechWeek Mixer", date: Date().addingTimeInterval(-8 * 3600))
        ]

        // Priya's card was requested, so the user's profile was shared with her.
        connections.append(
            Connection(
                card: priya,
                metAt: "TechWeek Mixer",
                metOn: Date().addingTimeInterval(-26 * 3600),
                origin: .request,
                grantedTier: .publicTier
            )
        )
    }

    // MARK: - Derived state

    var visibility: VisibilityMode { owner.visibility }

    var currentRoom: Room? { rooms.first { $0.membership == .joined } }

    /// People live in the user's current room, excluding the user.
    var liveInRoom: [BusinessCard] {
        guard let room = currentRoom, visibility != .dark else { return [] }
        let pool = discoverable + connections.map(\.card)
        return room.attendeeIDs.compactMap { id in
            pool.first { $0.id == id && $0.visibility.isDiscoverable }
        }
    }

    var storyRing: [BusinessCard] { liveInRoom.filter(\.hasActiveStories) }

    var incomingRequests: [AccessRequest] {
        // Stale requests from people who are already connected must never
        // surface — approving them would be a no-op.
        let connectedIDs = Set(connections.map(\.card.id))
        return requests.filter {
            $0.direction == .incoming && $0.status == .pending && !connectedIDs.contains($0.card.id)
        }
    }

    var outgoingRequests: [AccessRequest] {
        requests.filter { $0.direction == .outgoing && $0.status == .pending }
    }

    var favoriteConnections: [Connection] { connections.filter(\.isFavorite) }

    func isRemote(_ room: Room) -> Bool { remoteRoomIDs.contains(room.id) }

    /// Events the owner is hosting.
    var hostedRooms: [Room] { rooms.filter { $0.hostID == owner.id } }

    /// The person hosting a room, resolved from the people we know.
    func host(of room: Room) -> BusinessCard? {
        guard let hostID = room.hostID else { return nil }
        let pool = discoverable + connections.map(\.card)
        return pool.first { $0.id == hostID }
    }

    func isHost(of room: Room) -> Bool { room.hostID == owner.id }

    func card(withID id: UUID) -> BusinessCard? {
        let pool = discoverable + connections.map(\.card)
        return pool.first { $0.id == id }
    }

    /// Real count of rooms the user is currently in — no fabricated padding.
    var roomsAttended: Int { rooms.filter { $0.membership == .joined }.count }

    var sortedConnections: [Connection] {
        switch rolodexSort {
        case .recent: connections.sorted { $0.metOn > $1.metOn }
        case .name: connections.sorted { $0.card.name < $1.card.name }
        case .company: connections.sorted { $0.card.company < $1.card.company }
        }
    }

    func filteredConnections(query: String) -> [Connection] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return sortedConnections }
        return sortedConnections.filter { connection in
            let card = connection.card
            let haystack = [card.name, card.title, card.company, card.industry, card.location, connection.metAt]
            return haystack.contains { $0.localizedStandardContains(query) }
        }
    }

    func searchPeople(query: String) -> [BusinessCard] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let pool = discoverable + connections.map(\.card)
        return pool.filter { card in
            [card.name, card.title, card.company, card.industry, card.location, card.skills.joined(separator: " ")]
                .contains { $0.localizedStandardContains(trimmed) }
        }
    }

    func searchRooms(query: String) -> [Room] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return rooms }
        return rooms.filter { room in
            [room.name, room.venue, room.city, room.blurb].contains { $0.localizedStandardContains(trimmed) }
        }
    }

    func connection(for cardID: UUID) -> Connection? {
        connections.first { $0.card.id == cardID }
    }

    func isConnected(_ card: BusinessCard) -> Bool {
        connections.contains { $0.card.id == card.id }
    }

    func isPending(_ card: BusinessCard) -> Bool {
        pendingConnectionIDs.contains(card.id)
    }

    /// All stored messages, loaded through the message repository.
    var messages: [Message] { messageRepository.messages }

    /// Message threads with connected people, most recently active first.
    var conversations: [Conversation] {
        connections.compactMap { connection in
            let partnerID = connection.card.id
            let thread = messages
                .filter {
                    ($0.senderID == partnerID && $0.recipientID == owner.id)
                        || ($0.senderID == owner.id && $0.recipientID == partnerID)
                }
                .sorted { $0.sentAt < $1.sentAt }
            guard !thread.isEmpty else { return nil }

            let marker = readMarkers[partnerID] ?? .distantPast
            let unread = thread.filter { $0.senderID != owner.id && $0.sentAt > marker }.count
            return Conversation(partner: connection.card, messages: thread, unreadCount: unread)
        }
        .sorted { ($0.lastMessage?.sentAt ?? .distantPast) > ($1.lastMessage?.sentAt ?? .distantPast) }
    }

    var unreadMessageCount: Int { conversations.reduce(0) { $0 + $1.unreadCount } }

    /// Messages exchanged with one person, oldest first.
    func messages(with cardID: UUID) -> [Message] {
        messages
            .filter {
                ($0.senderID == cardID && $0.recipientID == owner.id)
                    || ($0.senderID == owner.id && $0.recipientID == cardID)
            }
            .sorted { $0.sentAt < $1.sentAt }
    }

    // MARK: - Mutations

    func setVisibility(_ mode: VisibilityMode) {
        owner.visibility = mode
        persistOwner()
    }

    func updateOwner(_ transform: (inout BusinessCard) -> Void) {
        transform(&owner)
        persistOwner()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: onboardingKey)
        persistOwner()
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        defaults.set(false, forKey: onboardingKey)
    }

    func toggleFavorite(_ connectionID: UUID) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        connections[index].isFavorite.toggle()
    }

    func updateNote(_ note: String, for connectionID: UUID) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        connections[index].note = note
    }

    /// Removes a connection and tears down everything tied to the
    /// relationship: messages, requests, pending state and read markers.
    func removeConnection(_ connectionID: UUID) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        let card = connections[index].card
        connections.remove(at: index)
        if !discoverable.contains(where: { $0.id == card.id }) {
            discoverable.append(card)
        }

        // Relationship cleanup — nothing about this person may linger.
        pendingConnectionIDs.remove(card.id)
        readMarkers[card.id] = nil
        persistReadMarkers()
        replyTasks[card.id]?.cancel()
        replyTasks[card.id] = nil
        requests.removeAll { $0.card.id == card.id }
        messageRepository.removeMessages(with: card.id)
    }

    /// Sends an in-app message to a connection. In the development build a
    /// simulated reply follows; a real backend would deliver incoming messages.
    func sendMessage(_ text: String, to cardID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, connection(for: cardID) != nil else { return }
        messageRepository.add(Message(senderID: owner.id, recipientID: cardID, text: trimmed))
        scheduleSimulatedReply(from: cardID)
    }

    /// Marks a thread as read so its unread badge clears once opened.
    func markThreadRead(_ cardID: UUID) {
        readMarkers[cardID] = Date()
        persistReadMarkers()
    }

    /// Development simulation only: schedules one canned reply through the
    /// local mock repository. Never runs against a real repository, is tracked
    /// so it can be cancelled, and re-validates the relationship before
    /// appending so the task cannot resurrect state for a removed connection.
    private func scheduleSimulatedReply(from cardID: UUID) {
        guard let repository = messageRepository as? LocalMessageRepository else { return }
        replyTasks[cardID]?.cancel()
        replyTasks[cardID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, let self else { return }
            defer { self.replyTasks[cardID] = nil }
            guard self.connection(for: cardID) != nil else { return }
            self.messageRepository.add(repository.makeSimulatedReply(from: cardID))
        }
    }

    private func persistReadMarkers() {
        do {
            let data = try JSONEncoder().encode(readMarkers)
            defaults.set(data, forKey: readMarkersKey)
        } catch {
            Log.persistence.error("Failed to persist read markers: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Sends a connection request to someone discovered in a room.
    func requestConnection(with card: BusinessCard) {
        guard !isConnected(card), !isPending(card) else { return }
        pendingConnectionIDs.insert(card.id)
    }

    /// Completes an exchange — the card lands in the rolodex immediately.
    @discardableResult
    func exchangeCards(with card: BusinessCard, at place: String) -> Connection {
        pendingConnectionIDs.remove(card.id)
        if let existing = connection(for: card.id) { return existing }

        let connection = Connection(
            card: card,
            metAt: place,
            metOn: Date(),
            origin: .exchange,
            // What they share can never exceed their own visibility ceiling.
            grantedTier: .connected.clamped(by: card.visibility.maxShareableTier)
        )
        connections.insert(connection, at: 0)
        discoverable.removeAll { $0.id == card.id }
        activity.insert(
            ActivityItem(card: card, kind: .exchanged, detail: place, date: Date()),
            at: 0
        )
        return connection
    }

    /// Asks a contact to unlock more of their card. Duplicate pending
    /// requests are collapsed so repeated taps cannot stack requests.
    func requestAccess(from connectionID: UUID, tier: AccessTier = .trusted) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        guard !connections[index].accessRequestPending,
              !requests.contains(where: {
                  $0.card.id == connections[index].card.id
                      && $0.direction == .outgoing
                      && $0.status == .pending
              }) else { return }
        connections[index].accessRequestPending = true
        let card = connections[index].card
        requests.insert(
            AccessRequest(
                card: card,
                direction: .outgoing,
                requestedTier: tier,
                createdAt: Date(),
                context: connections[index].metAt
            ),
            at: 0
        )
        activity.insert(
            ActivityItem(card: card, kind: .requestSent, detail: "you asked for more access", date: Date()),
            at: 0
        )
    }

    /// Requests someone's card. Only your profile is shared with them, so
    /// they know who is asking — they then grant or deny access within the
    /// limits of their own privacy settings.
    func requestCardAccess(to card: BusinessCard, tier: AccessTier = .connected) {
        let hasPending = requests.contains {
            $0.card.id == card.id && $0.direction == .outgoing && $0.status == .pending
        }
        guard !hasPending, !isConnected(card) else { return }

        // Only ask for what their privacy settings could actually grant.
        let tier = tier.clamped(by: card.visibility.maxShareableTier)
        let place = currentRoom?.name ?? "Cardex"
        if let existing = connection(for: card.id) {
            if let index = connections.firstIndex(where: { $0.id == existing.id }) {
                connections[index].accessRequestPending = true
            }
        } else {
            let connection = Connection(
                card: card,
                metAt: place,
                metOn: Date(),
                origin: .request,
                grantedTier: .publicTier,
                accessRequestPending: true
            )
            connections.insert(connection, at: 0)
            discoverable.removeAll { $0.id == card.id }
        }
        pendingConnectionIDs.insert(card.id)
        requests.insert(
            AccessRequest(card: card, direction: .outgoing, requestedTier: tier, createdAt: Date(), context: place),
            at: 0
        )
        activity.insert(
            ActivityItem(card: card, kind: .requestSent, detail: "you requested their card", date: Date()),
            at: 0
        )
    }

    func resolveRequest(_ requestID: UUID, approve: Bool, tier: AccessTier? = nil) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].status = approve ? .approved : .declined
        if let tier { requests[index].requestedTier = tier }

        if approve, requests[index].direction == .outgoing,
           let connectionIndex = connections.firstIndex(where: { $0.card.id == requests[index].card.id }) {
            // The other person grants access only within the ceiling their
            // own visibility mode allows.
            let ceiling = connections[connectionIndex].card.visibility.maxShareableTier
            connections[connectionIndex].grantedTier = requests[index].requestedTier.clamped(by: ceiling)
            connections[connectionIndex].accessRequestPending = false
            pendingConnectionIDs.remove(requests[index].card.id)
        }

        // Approving an incoming request brings them into your network —
        // they already received your profile when they asked. The tier you
        // grant is capped by your own privacy settings.
        if approve, requests[index].direction == .incoming,
           connection(for: requests[index].card.id) == nil {
            let ceiling = owner.visibility.maxShareableTier
            let connection = Connection(
                card: requests[index].card,
                metAt: requests[index].context,
                metOn: Date(),
                origin: .request,
                grantedTier: requests[index].requestedTier.clamped(by: ceiling)
            )
            connections.insert(connection, at: 0)
            discoverable.removeAll { $0.id == connection.card.id }
        }
    }

    /// Simulates the card owner approving the user's outgoing request.
    /// The grant is clamped to the ceiling of the contact's own visibility
    /// mode — they can never share beyond it (client-side only; a production
    /// backend must enforce this authoritatively).
    func grantTier(_ tier: AccessTier, to connectionID: UUID) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        connections[index].grantedTier = tier.clamped(by: connections[index].card.visibility.maxShareableTier)
        connections[index].accessRequestPending = false
    }

    func enterRoom(_ roomID: UUID, remotely: Bool = false) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        switch rooms[index].access {
        case .openDoor:
            joinRoom(at: index, remotely: remotely)
        case .request:
            if remotely {
                // Virtual entry skips the physical door check.
                joinRoom(at: index, remotely: true)
            } else {
                rooms[index].membership = .pending
            }
        case .ticketed:
            // Entry requires a ticket; the UI presents payment first and
            // completes through purchaseTicket(_:).
            break
        }
    }

    /// Pays for a ticketed event through the configured payment processor and
    /// steps inside. The default processor is a simulation — no real charge is
    /// made and no payment data is collected (see PRODUCTION_READINESS.md).
    func purchaseTicket(_ roomID: UUID) async throws {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[index].access == .ticketed,
              rooms[index].membership != .joined else { return }
        let price = rooms[index].ticketPrice ?? 0
        let name = rooms[index].name

        try await paymentProcessor.processTicketPurchase(amount: price, currency: "GBP", event: name)

        // Re-resolve after the await: state may have changed during payment.
        guard let currentIndex = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[currentIndex].membership != .joined else { return }
        joinRoom(at: currentIndex, remotely: false)
        activity.insert(
            ActivityItem(card: owner, kind: .ticketPurchased, detail: name, date: Date()),
            at: 0
        )
    }

    /// Creates an event and steps in as its host. A few known people
    /// immediately ask to come in so the host dashboard has work to do.
    @discardableResult
    func createEvent(
        name: String,
        venue: String,
        city: String,
        blurb: String,
        imageName: String,
        access: Room.Access,
        ticketPrice: Double? = nil
    ) -> Room {
        let pool = discoverable + connections.map(\.card)
        let room = Room(
            name: name,
            venue: venue,
            city: city,
            blurb: blurb,
            imageName: imageName,
            distanceMiles: (Double.random(in: 0.3...2.5) * 10).rounded() / 10,
            liveCount: 1,
            access: access,
            membership: .joined,
            attendeeIDs: [owner.id],
            hostID: owner.id,
            ticketPrice: access == .ticketed ? ticketPrice : nil,
            pendingAttendeeIDs: pool.prefix(3).map(\.id)
        )
        rooms.insert(room, at: 0)
        activity.insert(
            ActivityItem(card: owner, kind: .eventCreated, detail: name, date: Date()),
            at: 0
        )
        return room
    }

    /// Host approves someone waiting at the door of their event.
    func approveEntry(roomID: UUID, cardID: UUID) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        guard let pendingIndex = rooms[index].pendingAttendeeIDs.firstIndex(of: cardID) else { return }
        rooms[index].pendingAttendeeIDs.remove(at: pendingIndex)
        rooms[index].attendeeIDs.append(cardID)
        rooms[index].liveCount += 1
        if let card = card(withID: cardID) {
            activity.insert(
                ActivityItem(card: card, kind: .joinedRoom, detail: rooms[index].name, date: Date()),
                at: 0
            )
        }
    }

    /// Host declines someone waiting at the door.
    func denyEntry(roomID: UUID, cardID: UUID) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].pendingAttendeeIDs.removeAll { $0 == cardID }
    }

    /// Instantly moves the user into another room, attending remotely.
    func switchToRoom(_ roomID: UUID) {
        enterRoom(roomID, remotely: true)
    }

    func leaveRoom(_ roomID: UUID) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].membership = .none
        rooms[index].isBroadcasting = false
        remoteRoomIDs.remove(roomID)
    }

    /// Host starts or stops a live broadcast of their event.
    func toggleBroadcast(roomID: UUID) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].isBroadcasting.toggle()
    }

    private func joinRoom(at index: Int, remotely: Bool) {
        let roomID = rooms[index].id
        for other in rooms.indices where rooms[other].membership == .joined {
            rooms[other].membership = .none
            remoteRoomIDs.remove(rooms[other].id)
        }
        rooms[index].membership = .joined
        if remotely {
            remoteRoomIDs.insert(roomID)
        } else {
            remoteRoomIDs.remove(roomID)
        }
    }

    func toggleApplause(_ postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].hasApplauded.toggle()
        posts[index].applauds += posts[index].hasApplauded ? 1 : -1
    }

    func publishPost(body: String, audience: FeedPost.Audience, imageName: String?) {
        let post = FeedPost(
            author: owner,
            body: body,
            imageName: imageName,
            postedAt: Date(),
            audience: audience
        )
        posts.insert(post, at: 0)
    }

    func postStory(imageName: String, caption: String, imageData: Data? = nil) {
        owner.stories.insert(
            StoryUpdate(imageName: imageName, caption: caption, postedAt: Date(), imageData: imageData),
            at: 0
        )
        persistOwner()
    }

    // MARK: - Persistence

    private func persistOwner() {
        do {
            let data = try JSONEncoder().encode(owner)
            defaults.set(data, forKey: ownerKey)
        } catch {
            Log.persistence.error("Failed to persist owner card: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}

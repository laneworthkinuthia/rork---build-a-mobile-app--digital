import SwiftUI

/// Discover tab: nearby rooms you can walk into or request to join, plus
/// people search across the network.
struct DiscoverView: View {
    @Environment(CardexStore.self) private var store
    @State private var query = ""
    @State private var selectedRoom: Room?
    @State private var previewCard: BusinessCard?
    @State private var ticketRoom: Room?
    @State private var hostingRoom: Room?
    @State private var isCreatingEvent = false
    /// The create-event icon reveals itself once the page is scrolled down.
    @State private var isCreateVisible = false

    private var rooms: [Room] { store.searchRooms(query: query) }
    private var people: [BusinessCard] { store.searchPeople(query: query) }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        ScreenHeader(title: "Discover", caption: "Find rooms. Meet people. Build your network.")

                        if !store.hostedRooms.isEmpty {
                            hostedEventsSection
                        }

                        searchField

                        if !people.isEmpty {
                            SectionHeader(title: "People") {
                                Text("\(people.count)")
                                    .font(.system(size: 15, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            LazyVStack(spacing: 10) {
                                ForEach(people) { card in
                                    Button { previewCard = card } label: {
                                        SearchPersonRow(card: card, isConnected: store.isConnected(card))
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .padding(.horizontal, Theme.margin)
                        }

                        SectionHeader(title: query.isEmpty ? "Nearby Rooms" : "Rooms") {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill").font(.system(size: 10))
                                Text("London").font(.system(size: 14))
                            }
                            .foregroundStyle(Theme.textSecondary)
                        }

                        if rooms.isEmpty {
                            EmptyStateView(
                                symbol: "mappin.slash",
                                title: "No rooms found",
                                message: "Try a different search, or check back when an event starts nearby."
                            )
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(rooms) { room in
                                    RoomCard(
                                        room: room,
                                        isRemote: store.isRemote(room),
                                        onJoin: {
                                            if room.access == .ticketed {
                                                ticketRoom = room
                                            } else {
                                                store.enterRoom(room.id)
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }
                                        },
                                        onJoinRemotely: {
                                            if room.access == .ticketed && room.membership != .joined {
                                                ticketRoom = room
                                            } else {
                                                store.enterRoom(room.id, remotely: true)
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            }
                                        },
                                        onOpen: {
                                            selectedRoom = room
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.margin)
                        }
                    }
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    withAnimation(Theme.snappy) { isCreateVisible = offset > 28 }
                }
            }
            .overlay(alignment: .top) {
                if isCreateVisible {
                    Button { isCreatingEvent = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: .circle)
                            .overlay { Circle().strokeBorder(Theme.hairline, lineWidth: 0.8) }
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Create event")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedRoom) { room in
                RoomDetailSheet(roomID: room.id)
            }
            .sheet(item: $previewCard) { card in
                CardPreviewSheet(card: card)
            }
            .sheet(item: $ticketRoom) { room in
                TicketSheet(roomID: room.id)
            }
            .sheet(item: $hostingRoom) { room in
                HostEventView(roomID: room.id)
            }
            .sheet(isPresented: $isCreatingEvent) {
                CreateEventSheet()
            }
        }
    }

    /// Your events sit right at the top so anyone can host and manage them.
    private var hostedEventsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Your Events")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.hostedRooms) { room in
                        Button { hostingRoom = room } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Color(Theme.surfaceHigh)
                                    .frame(width: 190, height: 88)
                                    .overlay {
                                        CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                                    }
                                    .overlay {
                                        LinearGradient(colors: [.black.opacity(0.68), .clear], startPoint: .bottom, endPoint: .top)
                                    }
                                    .overlay(alignment: .bottomLeading) {
                                        if room.isBroadcasting {
                                            HStack(spacing: 4) {
                                                Circle().fill(.red).frame(width: 6, height: 6)
                                                Text("LIVE")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .tracking(0.8)
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.red.opacity(0.85), in: .capsule)
                                            .padding(8)
                                        }
                                    }
                                    .clipShape(.rect(cornerRadius: 13))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(room.attendeeIDs.count) inside · \(room.pendingAttendeeIDs.count) waiting")
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                            .frame(width: 190)
                            .panel(radius: Theme.tileRadius)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Theme.margin)
            }
            .contentMargins(.horizontal, -Theme.margin)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search rooms, people, companies", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    withAnimation(Theme.snappy) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(Theme.surface, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.hairline, lineWidth: 0.6) }
        .padding(.horizontal, Theme.margin)
    }
}

/// Nearby room card with a photo, access badge and the matching join action.
struct RoomCard: View {
    let room: Room
    var isRemote: Bool = false
    let onJoin: () -> Void
    let onJoinRemotely: () -> Void
    let onOpen: () -> Void

    private var badgeTint: Color {
        switch room.access {
        case .openDoor: Theme.openDoor
        case .ticketed: Theme.accent
        case .request: Theme.textSecondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                Color(Theme.surfaceHigh)
                    .frame(height: 148)
                    .overlay {
                        CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                    }
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.75), .black.opacity(0.1)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    }
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 6) {
                            if isRemote {
                                TagPill(text: "Remote", symbol: "video.fill", tint: Theme.accent)
                                    .background(.ultraThinMaterial, in: .capsule)
                            }
                            if room.access == .ticketed {
                                TagPill(text: room.priceLabel, symbol: "ticket.fill", tint: .white)
                                    .background(.ultraThinMaterial, in: .capsule)
                            }
                            TagPill(
                                text: room.access.badge,
                                symbol: room.access.symbol,
                                tint: badgeTint
                            )
                            .background(.ultraThinMaterial, in: .capsule)
                        }
                        .padding(12)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(room.name)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 10) {
                                Label(room.distanceLabel, systemImage: "location.fill")
                                Label("\(room.liveCount) live", systemImage: "person.2.fill")
                            }
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(14)
                    }
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
            }
            .buttonStyle(.pressable)

            VStack(alignment: .leading, spacing: 12) {
                Text(room.blurb)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                joinButton
            }
            .padding(14)
        }
        .panel(radius: Theme.cardRadius)
    }

    @ViewBuilder
    private var joinButton: some View {
        switch room.membership {
        case .joined:
            HStack(spacing: 7) {
                Image(systemName: isRemote ? "video.fill" : "checkmark.circle.fill").font(.system(size: 14))
                Text(isRemote ? "You're in · attending remotely" : "You're in this room")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.openDoor)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.openDoor.opacity(0.14), in: .rect(cornerRadius: 13))

        case .pending:
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "hourglass").font(.system(size: 14))
                    Text("Request sent").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.warning)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.warning.opacity(0.12), in: .rect(cornerRadius: 13))

                remoteButton
            }

        case .none:
            HStack(spacing: 10) {
                Button(action: onJoin) {
                    HStack(spacing: 7) {
                        Image(systemName: joinSymbol)
                            .font(.system(size: 14))
                        Text(joinTitle).font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(room.access == .request ? Theme.textPrimary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        room.access == .request ? Theme.surfaceHigh : Theme.accent,
                        in: .rect(cornerRadius: 13)
                    )
                }
                .buttonStyle(.pressable)

                remoteButton
            }
        }
    }

    /// Title for the primary action, including the ticket price when paid.
    private var joinTitle: String {
        room.access == .ticketed ? "Buy ticket · \(room.priceLabel)" : room.access.actionTitle
    }

    private var joinSymbol: String {
        switch room.access {
        case .openDoor: "arrow.right.circle.fill"
        case .request: "paperplane.fill"
        case .ticketed: "ticket.fill"
        }
    }

    /// Square button that joins the room remotely — works for every room.
    private var remoteButton: some View {
        Button(action: onJoinRemotely) {
            Image(systemName: "video.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 13))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Join \(room.name) remotely")
    }
}

/// Compact person row used for search results.
struct SearchPersonRow: View {
    let card: BusinessCard
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            StoryAvatar(card: card, size: 48, isLive: card.visibility == .live)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(card.title), \(card.company)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text(card.location)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.openDoor)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(12)
        .panel(radius: Theme.rowRadius)
    }
}

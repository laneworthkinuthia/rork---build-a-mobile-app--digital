import SwiftUI

/// Room detail: who is inside, what the room is for, and how to get in.
struct RoomDetailSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let roomID: UUID
    @State private var previewCard: BusinessCard?
    @State private var isShowingTicket = false
    @State private var isManaging = false

    private var room: Room? { store.rooms.first { $0.id == roomID } }

    private var attendees: [BusinessCard] {
        guard let room else { return [] }
        let pool = store.discoverable + store.connections.map(\.card)
        return room.attendeeIDs.compactMap { id in
            pool.first { $0.id == id && $0.visibility.isDiscoverable }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if let room {
                    ScrollView {
                        VStack(spacing: 18) {
                            banner(room)

                            HStack(spacing: 8) {
                                TagPill(
                                    text: room.access.badge,
                                    symbol: room.access.symbol,
                                    tint: room.access == .openDoor ? Theme.openDoor : (room.access == .ticketed ? Theme.accent : Theme.textSecondary)
                                )
                                if room.access == .ticketed {
                                    TagPill(text: room.priceLabel, symbol: "sterlingsign", tint: Theme.accent)
                                }
                                TagPill(text: room.distanceLabel, symbol: "location.fill")
                                TagPill(text: "\(room.liveCount) live", symbol: "person.2.fill", tint: Theme.accent)
                                Spacer(minLength: 0)
                            }

                            if let host = store.host(of: room) {
                                HStack(spacing: 10) {
                                    Avatar(card: host, size: 30)
                                    Text("Hosted by \(host.name)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text(room.blurb)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if room.access == .request, room.membership != .joined {
                                accessNote
                            }

                            if room.access == .ticketed, room.membership != .joined {
                                ticketNote(room)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text(room.membership == .joined ? "People in this room" : "Who's inside")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)

                                if attendees.isEmpty {
                                    Text("Nobody is visible in this room right now.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textTertiary)
                                } else {
                                    ForEach(attendees) { card in
                                        Button { previewCard = card } label: {
                                            SearchPersonRow(card: card, isConnected: store.isConnected(card))
                                        }
                                        .buttonStyle(.pressable)
                                        .blur(radius: room.membership == .joined ? 0 : 3.5)
                                        .disabled(room.membership != .joined)
                                    }
                                }
                            }
                        }
                        .padding(Theme.margin)
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom) { actionBar(room) }
                }
            }
            .navigationTitle(room?.name ?? "Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $previewCard) { card in
                CardPreviewSheet(card: card)
            }
            .sheet(isPresented: $isShowingTicket) {
                TicketSheet(roomID: roomID)
            }
            .sheet(isPresented: $isManaging) {
                HostEventView(roomID: roomID)
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private func banner(_ room: Room) -> some View {
        Color(Theme.surfaceHigh)
            .frame(height: 170)
            .overlay {
                CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
            }
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(room.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(room.venue) · \(room.city)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(16)
            }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
    }

    private var accessNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.warning)
                .frame(width: 38, height: 38)
                .background(Theme.warning.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("Approval needed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("The host reviews requests before you can see who's inside.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .panel()
    }

    private func ticketNote(_ room: Room) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tickets · \(room.priceLabel)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Entry to this event requires a ticket — in person or remote.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .panel()
    }

    private func actionBar(_ room: Room) -> some View {
        Group {
            if store.isHost(of: room) {
                Button {
                    isManaging = true
                } label: {
                    PrimaryButtonLabel(title: "Manage Event", symbol: "slider.horizontal.3")
                }
                .buttonStyle(.pressable)
            } else {
                switch room.membership {
                case .joined:
                    Button {
                        store.leaveRoom(room.id)
                        dismiss()
                    } label: {
                        SecondaryButtonLabel(title: "Leave room", symbol: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.pressable)

                case .pending:
                    HStack(spacing: 10) {
                        SecondaryButtonLabel(title: "Request pending", symbol: "hourglass")
                        remoteJoinButton(room)
                    }

                case .none:
                    HStack(spacing: 10) {
                        Button {
                            if room.access == .ticketed {
                                isShowingTicket = true
                            } else {
                                store.enterRoom(room.id)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if room.access == .openDoor { dismiss() }
                            }
                        } label: {
                            PrimaryButtonLabel(
                                title: room.access == .ticketed ? "Buy ticket · \(room.priceLabel)" : room.access.actionTitle,
                                symbol: room.access == .openDoor ? "arrow.right.circle.fill" : (room.access == .ticketed ? "ticket.fill" : "paperplane.fill")
                            )
                        }
                        .buttonStyle(.pressable)

                        if room.access != .ticketed {
                            remoteJoinButton(room)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    /// Joins instantly, attending remotely — no host approval needed.
    private func remoteJoinButton(_ room: Room) -> some View {
        Button {
            store.enterRoom(room.id, remotely: true)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } label: {
            Image(systemName: "video.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 50, height: 50)
                .background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent.opacity(0.4), lineWidth: 0.8)
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Join \(room.name) remotely")
    }
}

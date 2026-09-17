import SwiftUI

/// The host dashboard for an event: monitor who is inside, approve
/// people at the door, go live and share the event.
struct HostEventView: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let roomID: UUID
    @State private var isSharing = false

    private var room: Room? { store.rooms.first { $0.id == roomID } }

    private func cards(in ids: [UUID]) -> [BusinessCard] {
        let pool = store.discoverable + store.connections.map(\.card)
        return ids.compactMap { id in pool.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if let room {
                    ScrollView {
                        VStack(spacing: 18) {
                            banner(room)
                            statsRow(room)
                            hostControls(room)
                            pendingSection(room)
                            attendeeSection(room)
                        }
                        .padding(Theme.margin)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Your Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private func banner(_ room: Room) -> some View {
        Color(Theme.surfaceHigh)
            .frame(height: 150)
            .overlay {
                CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.72), .clear], startPoint: .bottom, endPoint: .top)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("\(room.venue) · \(room.city)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                    if room.isBroadcasting {
                        HStack(spacing: 5) {
                            Circle().fill(.red).frame(width: 7, height: 7)
                            Text("LIVE").font(.system(size: 11, weight: .bold)).tracking(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.red.opacity(0.85), in: .capsule)
                    }
                }
                .padding(14)
            }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
    }

    private func statsRow(_ room: Room) -> some View {
        HStack(spacing: 10) {
            statTile(value: "\(room.attendeeIDs.count)", label: "Inside", symbol: "person.2.fill")
            statTile(value: "\(room.pendingAttendeeIDs.count)", label: "At the door", symbol: "door.left.hand.open")
            statTile(
                value: room.isFree ? "Free" : room.priceLabel,
                label: "Ticket",
                symbol: "ticket.fill"
            )
        }
    }

    private func statTile(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .panel(radius: Theme.tileRadius)
    }

    private func hostControls(_ room: Room) -> some View {
        VStack(spacing: 0) {
            Button {
                store.toggleBroadcast(roomID: room.id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: room.isBroadcasting ? "stop.circle.fill" : "video.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(room.isBroadcasting ? .red : Theme.accent)
                        .frame(width: 40, height: 40)
                        .background((room.isBroadcasting ? Color.red : Theme.accent).opacity(0.14), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.isBroadcasting ? "Stop live broadcast" : "Go live")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(room.isBroadcasting ? "Attendees can see the room is live" : "Share the room as it happens")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if room.isBroadcasting {
                        Circle().fill(.red).frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)

            Divider().overlay(Theme.hairline).padding(.leading, 66)

            ShareLink(
                item: "Join me at \(room.name) — \(room.venue), \(room.city). Get in with Cardex: cardex://room/\(room.id.uuidString)",
                subject: Text(room.name)
            ) {
                HStack(spacing: 13) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Theme.surfaceHigh, in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Share event")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Post to social, messages or email")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
        }
        .panel()
    }

    @ViewBuilder
    private func pendingSection(_ room: Room) -> some View {
        let waiting = cards(in: room.pendingAttendeeIDs)
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Waiting to get in")

                VStack(spacing: 0) {
                    ForEach(Array(waiting.enumerated()), id: \.element.id) { index, card in
                        HStack(spacing: 12) {
                            Avatar(card: card, size: 44)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(card.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(card.title), \(card.company)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Button {
                                store.denyEntry(roomID: room.id, cardID: card.id)
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 38, height: 38)
                                    .background(Theme.surfaceHigh, in: .rect(cornerRadius: 11))
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("Deny \(card.name) entry")

                            Button {
                                store.approveEntry(roomID: room.id, cardID: card.id)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Theme.accent, in: .rect(cornerRadius: 11))
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("Approve \(card.name) entry")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < waiting.count - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, 66)
                        }
                    }
                }
                .panel()
            }
        }
    }

    @ViewBuilder
    private func attendeeSection(_ room: Room) -> some View {
        let inside = cards(in: room.attendeeIDs)

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Who's inside")

            if inside.isEmpty {
                EmptyStateView(
                    symbol: "person.2",
                    title: "Just you so far",
                    message: "Share the event or approve people at the door to fill the room."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(inside.enumerated()), id: \.element.id) { index, card in
                        HStack(spacing: 12) {
                            Avatar(card: card, size: 42)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(card.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(card.title), \(card.company)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if card.id == store.owner.id {
                                TagPill(text: "Host", symbol: "star.fill", tint: Theme.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < inside.count - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, 66)
                        }
                    }
                }
                .panel()
            }
        }
    }
}

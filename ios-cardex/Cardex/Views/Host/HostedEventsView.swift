import SwiftUI

/// The user's list of the events they host. Creating happens from Discover's
/// scroll-reveal create button.
struct HostedEventsView: View {
    @Environment(CardexStore.self) private var store
    @State private var selectedRoomID: UUID?

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if store.hostedRooms.isEmpty {
                        EmptyStateView(
                            symbol: "plus.rectangle.on.folder",
                            title: "No events yet",
                            message: "Create an event from Discover — scroll down and tap the plus at the top."
                        )
                    } else {
                        ForEach(store.hostedRooms) { room in
                            hostedRow(room)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Your Events")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: Binding(
            get: { selectedRoomID.flatMap { id in store.rooms.first { $0.id == id } } },
            set: { selectedRoomID = $0?.id }
        )) { room in
            HostEventView(roomID: room.id)
        }
    }

    private func hostedRow(_ room: Room) -> some View {
        Button { selectedRoomID = room.id } label: {
            VStack(spacing: 0) {
                Color(Theme.surfaceHigh)
                    .frame(height: 110)
                    .overlay {
                        CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                    }
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.72), .clear], startPoint: .bottom, endPoint: .top)
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 8) {
                            Text(room.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                            TagPill(
                                text: room.isFree ? room.access.badge : room.priceLabel,
                                symbol: room.isFree ? room.access.symbol : "ticket.fill",
                                tint: room.access == .ticketed && !room.isFree ? Theme.accent : .white
                            )
                            .background(.ultraThinMaterial, in: .capsule)
                        }
                        .padding(12)
                    }

                HStack(spacing: 10) {
                    Label("\(room.attendeeIDs.count) inside", systemImage: "person.2.fill")
                    if !room.pendingAttendeeIDs.isEmpty {
                        Label("\(room.pendingAttendeeIDs.count) waiting", systemImage: "door.left.hand.open")
                            .foregroundStyle(Theme.warning)
                    }
                    if room.isBroadcasting {
                        Label("Live", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.red)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .padding(12)
            }
            .panel(radius: Theme.cardRadius)
        }
        .buttonStyle(.pressable)
    }
}

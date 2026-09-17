import SwiftUI

/// Rooms the user already has access to — joined, hosting, or attending remotely.
struct MyRoomsView: View {
    @Environment(CardexStore.self) private var store
    @State private var selectedRoom: Room?

    private var accessibleRooms: [Room] {
        store.rooms.filter { $0.membership == .joined || store.isHost(of: $0) }
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(spacing: 12) {
                    if accessibleRooms.isEmpty {
                        EmptyStateView(
                            symbol: "door.left.hand.open",
                            title: "No rooms yet",
                            message: "Rooms you join or host on Discover show up here."
                        )
                    } else {
                        ForEach(accessibleRooms) { room in
                            roomRow(room)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("My Rooms")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedRoom) { room in
            RoomDetailSheet(roomID: room.id)
        }
    }

    private func roomRow(_ room: Room) -> some View {
        Button { selectedRoom = room } label: {
            VStack(spacing: 0) {
                Color(Theme.surfaceHigh)
                    .frame(height: 100)
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
                    if store.isHost(of: room) {
                        Label("Hosting", systemImage: "star.fill")
                            .foregroundStyle(Theme.accent)
                    } else if store.isRemote(room) {
                        Label("Remote", systemImage: "video.fill")
                            .foregroundStyle(Theme.accent)
                    } else {
                        Label("Inside", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.openDoor)
                    }

                    Text("\(room.venue), \(room.city)")
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(room.liveCount) live")
                        .monospacedDigit()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(12)
            }
            .panel(radius: Theme.cardRadius)
        }
        .buttonStyle(.pressable)
    }
}

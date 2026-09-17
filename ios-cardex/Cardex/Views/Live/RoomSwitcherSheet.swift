import SwiftUI

/// Switch between rooms without leaving the Live tab — every room can be
/// attended remotely, so switching is instant.
struct RoomSwitcherSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.rooms) { room in
                            roomRow(room)
                        }
                    }
                    .padding(.horizontal, Theme.margin)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func roomRow(_ room: Room) -> some View {
        let isCurrent = room.membership == .joined

        return HStack(spacing: 12) {
            Color(Theme.surfaceHigh)
                .frame(width: 68, height: 52)
                .overlay {
                    CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                }
                .clipShape(.rect(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill").font(.system(size: 9))
                    Text("\(room.liveCount) live")
                        .monospacedDigit()
                    Text("· \(room.city)")
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

                if isCurrent, store.isRemote(room) {
                    TagPill(text: "Remote", symbol: "video.fill", tint: Theme.accent)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 8)

            if isCurrent {
                HStack(spacing: 5) {
                    Circle().fill(Theme.openDoor).frame(width: 6, height: 6)
                    Text("Now")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.openDoor)

                Button {
                    store.leaveRoom(room.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Theme.surfaceHigh, in: .circle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Leave \(room.name)")
            } else if room.membership == .pending {
                Text("Pending")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.warning)
            } else {
                Button {
                    store.switchToRoom(room.id)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Text("Switch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Switch to \(room.name)")
            }
        }
        .padding(12)
        .panel(radius: Theme.rowRadius)
    }
}

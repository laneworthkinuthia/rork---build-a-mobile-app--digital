import SwiftUI

/// Rolodex row: a slim card-shaped strip carrying the person's identity.
struct ConnectionRow: View {
    let connection: Connection

    var body: some View {
        HStack(spacing: 14) {
            Color(Theme.surfaceHigh)
                .frame(width: 56, height: 72)
                .overlay {
                    CardPhoto(
                        imageName: connection.card.photoName,
                        monogram: connection.card.monogram,
                        palette: connection.card.palette
                    )
                }
                .overlay { connection.card.palette.vignette.allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(connection.card.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if connection.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.warning)
                    }
                }

                Text(connection.card.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(connection.card.company)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                    Text("·").foregroundStyle(Theme.textTertiary)
                    Text(connection.card.industry)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                if connection.accessRequestPending {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.warning)
                } else if !connection.lockedDetails.isEmpty {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(12)
        .panel(radius: Theme.rowRadius)
    }
}

/// Row used in Live and search results, with an inline connect action.
struct PersonRow: View {
    let card: BusinessCard
    let state: ConnectState
    var onAvatarTap: (() -> Void)?
    var onAction: () -> Void

    enum ConnectState {
        case connect
        case pending
        case connected

        var title: String {
            switch self {
            case .connect: "Connect"
            case .pending: "Pending"
            case .connected: "Connected"
            }
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            Button {
                onAvatarTap?()
            } label: {
                StoryAvatar(card: card, size: 54, isLive: card.visibility == .live)
            }
            .buttonStyle(.pressable)
            .disabled(onAvatarTap == nil)
            .accessibilityLabel(card.hasActiveStories ? "\(card.name), view recent updates" : card.name)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(card.title), \(card.company)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                    Text("In this room")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 4)

            Button(action: onAction) {
                Text(state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state == .connect ? .white : Theme.textSecondary)
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background(state == .connect ? Theme.accent : Theme.surfaceHigh, in: .capsule)
            }
            .buttonStyle(.pressable)
            .disabled(state != .connect)
        }
        .padding(12)
        .panel(radius: Theme.rowRadius)
    }
}

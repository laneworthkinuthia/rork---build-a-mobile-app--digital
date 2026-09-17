import SwiftUI

/// Lets the user ask a contact to unlock a higher tier of their card.
struct RequestAccessSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let connection: Connection
    @State private var tier: AccessTier = .trusted

    private var availableTiers: [AccessTier] {
        AccessTier.allCases.filter { $0.rank > connection.grantedTier.rank }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        HStack(spacing: 13) {
                            Avatar(card: connection.card, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.card.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(connection.card.title), \(connection.card.company)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .panel()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("What would you like to see?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)

                            ForEach(availableTiers) { option in
                                Button {
                                    withAnimation(Theme.snappy) { tier = option }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: tier == option ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(tier == option ? Theme.accent : Theme.textTertiary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.title)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(Theme.textPrimary)
                                            Text(option.caption)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.textSecondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(13)
                                    .background(
                                        tier == option ? Theme.accentSoft : Theme.surface,
                                        in: .rect(cornerRadius: Theme.rowRadius)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Theme.rowRadius)
                                            .strokeBorder(tier == option ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 0.8)
                                    }
                                }
                                .buttonStyle(.pressable)
                            }
                        }

                        HStack(spacing: 7) {
                            Image(systemName: "arrow.left.arrow.right.circle")
                                .font(.system(size: 12))
                            Text("Only your profile is shared, so they know who's asking. They can only grant what their privacy settings allow.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 4)

                        if !connection.lockedDetails.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENTLY LOCKED")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.4)
                                    .foregroundStyle(Theme.textTertiary)
                                ForEach(connection.lockedDetails) { detail in
                                    HStack(spacing: 8) {
                                        Image(systemName: detail.kind.symbol)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textTertiary)
                                        Text(detail.kind.label)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.textSecondary)
                                        Spacer(minLength: 0)
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .panel()
                        }
                    }
                    .padding(Theme.margin)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.requestAccess(from: connection.id, tier: tier)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    PrimaryButtonLabel(title: "Send Request", symbol: "paperplane.fill")
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Request Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                tier = availableTiers.last ?? .trusted
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }
}

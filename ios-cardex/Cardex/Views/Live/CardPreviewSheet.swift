import SwiftUI

/// Quick look at someone discovered in a room, before you connect with them.
struct CardPreviewSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let card: BusinessCard
    @State private var isFlipped = false
    @State private var isShowingStories = false

    private var publicDetails: [ContactDetail] {
        card.details.filter { $0.tier == .publicTier }
    }

    private var lockedDetails: [ContactDetail] {
        card.details.filter { $0.tier != .publicTier }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        FlippableCard(isFlipped: $isFlipped) {
                            BusinessCardFront(card: card)
                        } back: {
                            BusinessCardBack(
                                card: card,
                                visibleDetails: publicDetails,
                                lockedDetails: lockedDetails
                            )
                        }
                        .frame(height: 320)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            isFlipped.toggle()
                        }

                        HStack(spacing: 8) {
                            TagPill(text: card.industry, symbol: "briefcase.fill")
                            TagPill(
                                text: card.visibility.title,
                                symbol: card.visibility.symbol,
                                tint: card.visibility.tint
                            )
                            Spacer(minLength: 0)
                        }

                        if !store.isConnected(card), !store.isPending(card) {
                            HStack(spacing: 7) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("Only your profile is shared, so they know who's asking. They grant or deny access based on their privacy settings.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .foregroundStyle(Theme.textTertiary)
                        }

                        if card.hasActiveStories {
                            Button {
                                isShowingStories = true
                            } label: {
                                HStack(spacing: 12) {
                                    StoryAvatar(card: card, size: 44)
                                    Text("See \(card.firstName)'s recent updates")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .padding(14)
                                .panel()
                            }
                            .buttonStyle(.pressable)
                        }

                        if !card.skills.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Skills")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(card.skills, id: \.self) { TagPill(text: $0) }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .panel()
                        }
                    }
                    .padding(Theme.margin)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .navigationTitle(card.firstName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $isShowingStories) {
                StoryViewer(cards: [card], startIndex: 0)
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if store.isConnected(card) {
                SecondaryButtonLabel(title: "In your connections", symbol: "checkmark")
            } else if store.isPending(card) {
                SecondaryButtonLabel(title: "Request sent", symbol: "hourglass")
            } else {
                Button {
                    store.requestCardAccess(to: card)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    PrimaryButtonLabel(title: "Request Card", symbol: "paperplane.fill")
                }
                .buttonStyle(.pressable)

                Button {
                    let place = store.currentRoom?.name ?? "Cardex"
                    store.exchangeCards(with: card, at: place)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    SecondaryButtonLabel(title: "Exchange", symbol: "arrow.left.arrow.right")
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}

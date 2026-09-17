import SwiftUI

/// Incoming and outgoing access requests — the permission inbox.
struct RequestsView: View {
    @Environment(CardexStore.self) private var store
    @State private var scope: Scope = .incoming
    @State private var previewCard: BusinessCard?

    private enum Scope: String, CaseIterable, Identifiable {
        case incoming, outgoing
        var id: String { rawValue }
        var title: String { self == .incoming ? "Incoming" : "Sent" }
    }

    private var items: [AccessRequest] {
        scope == .incoming ? store.incomingRequests : store.outgoingRequests
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 6)

                    if items.isEmpty {
                        EmptyStateView(
                            symbol: "tray",
                            title: scope == .incoming ? "No requests" : "Nothing sent",
                            message: scope == .incoming
                                ? "When someone asks to meet you or access your card, it shows up here."
                                : "Requests you send to meet someone or unlock details appear here."
                        )
                    } else {
                        ForEach(items) { request in
                            requestCard(request)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Access Requests")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $previewCard) { card in
            CardPreviewSheet(card: card)
        }
    }

    private func requestCard(_ request: AccessRequest) -> some View {
        VStack(spacing: 14) {
            Button { previewCard = request.card } label: {
                HStack(spacing: 13) {
                    Avatar(card: request.card, size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.card.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(request.card.title), \(request.card.company)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            TagPill(text: request.requestedTier.title, symbol: "lock.open.fill", tint: Theme.accent)
                            Text(request.context)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.top, 3)
                    }

                    Spacer(minLength: 0)

                    Text(request.createdAt.shortRelativeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityHint("View their profile")

            if request.direction == .incoming {
                HStack(spacing: 10) {
                    Button {
                        store.resolveRequest(request.id, approve: false)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } label: {
                        SecondaryButtonLabel(title: "Decline")
                    }
                    .buttonStyle(.pressable)

                    Button {
                        store.resolveRequest(request.id, approve: true)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        PrimaryButtonLabel(title: "Approve")
                    }
                    .buttonStyle(.pressable)
                }

                HStack(spacing: 7) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 12))
                    Text("Only their profile is shared with you, so you know who's asking. Approving grants access up to what your privacy settings allow.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.warning)
                    Text("Waiting for \(request.card.firstName) to respond")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                    Text("Only your profile was shared, so they know who you are. They approve based on their privacy settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(14)
        .panel()
    }
}

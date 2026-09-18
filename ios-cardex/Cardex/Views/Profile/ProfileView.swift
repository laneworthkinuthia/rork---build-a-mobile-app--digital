import SwiftUI

/// Profile tab: your own card, visibility, access control and settings.
struct ProfileView: View {
    @Environment(CardexStore.self) private var store
    @State private var path: [ProfileRoute] = []
    @State private var isShowingModeSheet = false
    @State private var isShowingExchange = false
    @State private var isFlipped = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        ScreenHeader(title: "Profile", caption: "Your card. Your rules.") {
                            CircleIconButton(symbol: "qrcode") { isShowingExchange = true }
                        }

                        FlippableCard(isFlipped: $isFlipped) {
                            BusinessCardFront(card: store.owner)
                        } back: {
                            BusinessCardBack(
                                card: store.owner,
                                visibleDetails: store.owner.details,
                                lockedDetails: []
                            )
                        }
                        .frame(height: 300)
                        .padding(.horizontal, Theme.margin)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            isFlipped.toggle()
                        }

                        Button { path.append(.editor) } label: {
                            PrimaryButtonLabel(title: "Edit My Card", symbol: "wand.and.stars")
                        }
                        .buttonStyle(.pressable)
                        .padding(.horizontal, Theme.margin)

                        visibilityCard
                        settingsGroup
                    }
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .editor: CardEditorView()
                case .access: AccessControlView()
                case .requests: RequestsView()
                case .stories: MyStoriesView()
                case .events: HostedEventsView()
                case .messages: MessagesInboxView(path: $path)
                case .conversation(let id): ConversationView(partnerID: id)
                }
            }
            .sheet(isPresented: $isShowingModeSheet) { VisibilitySheet() }
            .fullScreenCover(isPresented: $isShowingExchange) { ExchangeView() }
        }
    }

    private var visibilityCard: some View {
        Button { isShowingModeSheet = true } label: {
            HStack(spacing: 14) {
                PulseGlyph(
                    symbol: store.visibility.symbol,
                    tint: store.visibility.tint,
                    isAnimating: store.visibility == .live
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Visibility · \(store.visibility.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.visibility.caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .panel()
            .padding(.horizontal, Theme.margin)
        }
        .buttonStyle(.pressable)
    }

    private var settingsGroup: some View {
        VStack(spacing: 0) {
            settingsRow(
                symbol: "calendar.badge.plus",
                title: "Your Events",
                caption: "Rooms you host, approve and go live in",
                badge: store.hostedRooms.isEmpty ? nil : "\(store.hostedRooms.count)"
            ) { path.append(.events) }

            Divider().overlay(Theme.hairline).padding(.leading, 66)

            settingsRow(
                symbol: "lock.shield.fill",
                title: "Access Control",
                caption: "Choose what each tier can see",
                badge: nil
            ) { path.append(.access) }

            Divider().overlay(Theme.hairline).padding(.leading, 66)

            settingsRow(
                symbol: "tray.full.fill",
                title: "Access Requests",
                caption: "People asking to see behind your card",
                badge: store.incomingRequests.isEmpty ? nil : "\(store.incomingRequests.count)"
            ) { path.append(.requests) }

            Divider().overlay(Theme.hairline).padding(.leading, 66)

            settingsRow(
                symbol: "bubble.left.and.bubble.right.fill",
                title: "Messages",
                caption: "Chat with people you've met",
                badge: store.unreadMessageCount == 0 ? nil : "\(store.unreadMessageCount)",
                identifier: "profile-messages-row"
            ) { path.append(.messages) }

            Divider().overlay(Theme.hairline).padding(.leading, 66)

            settingsRow(
                symbol: "photo.stack.fill",
                title: "My Updates",
                caption: "Photos that disappear after 24 hours",
                badge: store.owner.activeStories.isEmpty ? nil : "\(store.owner.activeStories.count)"
            ) { path.append(.stories) }
        }
        .panel()
        .padding(.horizontal, Theme.margin)
    }

    private func settingsRow(
        symbol: String,
        title: String,
        caption: String,
        badge: String?,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceHigh, in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Theme.accent, in: .capsule)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier ?? "")
    }
}

enum ProfileRoute: Hashable {
    case editor
    case access
    case requests
    case stories
    case events
    case messages
    case conversation(UUID)
}

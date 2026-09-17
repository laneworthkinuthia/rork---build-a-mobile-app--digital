import SwiftUI

/// Cards tab root: the owner's card on top, visibility control, stats and activity.
struct CardsHomeView: View {
    @Environment(CardexStore.self) private var store
    @State private var path: [CardsRoute] = []
    @State private var isShowingModeSheet = false
    @State private var isShowingExchange = false
    @State private var isFlipped = false

    var body: some View {
        @Bindable var store = store

        NavigationStack(path: $path) {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        ScreenHeader(title: "Your Card", caption: "Make connections. Open doors.") {
                            CircleIconButton(symbol: "qrcode") { isShowingExchange = true }
                        }

                        ownerCard
                        visibilityRow
                        statsRow
                        requestsSection
                        activitySection
                    }
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: CardsRoute.self) { route in
                switch route {
                case .rolodex:
                    RolodexView(path: $path)
                case .connection(let id):
                    if let connection = store.connections.first(where: { $0.id == id }) {
                        ConnectionDetailView(connectionID: connection.id)
                    }
                case .activity:
                    ActivityListView(path: $path)
                case .requests:
                    RequestsView()
                case .rooms:
                    MyRoomsView()
                }
            }
            .sheet(isPresented: $isShowingModeSheet) {
                VisibilitySheet()
            }
            .fullScreenCover(isPresented: $isShowingExchange) {
                ExchangeView()
            }
        }
    }

    private var ownerCard: some View {
        VStack(spacing: 14) {
            FlippableCard(isFlipped: $isFlipped) {
                BusinessCardFront(card: store.owner) {
                    Button {
                        isShowingExchange = true
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Show exchange code")
                }
            } back: {
                BusinessCardBack(
                    card: store.owner,
                    visibleDetails: store.owner.details,
                    lockedDetails: []
                )
            }
            .frame(height: 340)
            .padding(.horizontal, Theme.margin)
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                isFlipped.toggle()
            }

            Text(isFlipped ? "Tap to show the front" : "Tap the card to see your details")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var visibilityRow: some View {
        Button {
            isShowingModeSheet = true
        } label: {
            HStack(spacing: 14) {
                PulseGlyph(symbol: store.visibility.symbol, tint: store.visibility.tint, isAnimating: store.visibility == .live)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.visibility.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.visibility.caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
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

    private var statsRow: some View {
        HStack(spacing: 10) {
            Button { path.append(.rolodex) } label: {
                StatTile(value: "\(store.connections.count)", label: "Connections", symbol: "person.2.fill")
            }
            .buttonStyle(.pressable)

            Button { path.append(.requests) } label: {
                StatTile(value: "\(store.incomingRequests.count)", label: "Requests", symbol: "tray.fill")
            }
            .buttonStyle(.pressable)

            Button { path.append(.rooms) } label: {
                StatTile(value: "\(store.roomsAttended)", label: "Rooms", symbol: "door.left.hand.open")
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Theme.margin)
    }

    /// People who asked to meet you or access your card.
    @ViewBuilder
    private var requestsSection: some View {
        if !store.incomingRequests.isEmpty {
            VStack(spacing: 12) {
                SectionHeader(title: "Who Wants to Meet You") {
                    Button { path.append(.requests) } label: {
                        HStack(spacing: 3) {
                            Text("See All").font(.system(size: 15, weight: .medium))
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.pressable)
                }

                VStack(spacing: 0) {
                    ForEach(Array(store.incomingRequests.prefix(3).enumerated()), id: \.element.id) { index, request in
                        Button { path.append(.requests) } label: {
                            HStack(spacing: 12) {
                                Avatar(card: request.card, size: 42)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.card.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text("Wants \(request.requestedTier.title.lowercased()) access · \(request.context)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 4)

                                Text(request.createdAt.shortRelativeLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)

                        if index < min(3, store.incomingRequests.count) - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, 66)
                        }
                    }
                }
                .panel()
                .padding(.horizontal, Theme.margin)
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Recent Activity") {
                Button { path.append(.activity) } label: {
                    HStack(spacing: 3) {
                        Text("See All").font(.system(size: 15, weight: .medium))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.pressable)
            }

            VStack(spacing: 0) {
                ForEach(Array(store.activity.prefix(3).enumerated()), id: \.element.id) { index, item in
                    ActivityRow(item: item) {
                        if item.kind == .accessRequest {
                            path.append(.requests)
                        } else if let connection = store.connection(for: item.card.id) {
                            path.append(.connection(connection.id))
                        }
                    }
                    if index < min(3, store.activity.count) - 1 {
                        Divider().overlay(Theme.hairline).padding(.leading, 66)
                    }
                }
            }
            .panel()
            .padding(.horizontal, Theme.margin)
        }
    }
}

/// Routes pushed from the Cards tab.
enum CardsRoute: Hashable {
    case rolodex
    case connection(UUID)
    case activity
    case requests
    case rooms
}

/// Stat tile with monospaced digits.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .panel()
    }
}

/// Glyph that softly pulses while the user is live.
struct PulseGlyph: View {
    let symbol: String
    let tint: Color
    let isAnimating: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 42, height: 42)
                .scaleEffect(pulse ? 1.35 : 1)
                .opacity(pulse ? 0 : 0.9)

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 42, height: 42)

            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 44, height: 44)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            pulse = false
            guard newValue else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// One row in the recent activity list.
struct ActivityRow: View {
    let item: ActivityItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(card: item.card, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.headline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 9))
                        Text(item.detail)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(item.date.shortRelativeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}

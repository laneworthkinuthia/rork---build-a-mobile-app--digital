import SwiftUI

/// Root shell. Beta mode: sign-in gate → onboarding → five-tab wallet, with
/// connecting/offline states around the backend sync. Local mode (tests,
/// previews, UI tests) keeps the original offline behaviour. Guest preview
/// (development only, see `GuestPreviewConfig`) rides the local data path with
/// isolated defaults and is entered from the sign-in gate.
struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @State private var store: CardexStore
    @State private var isGuestPreview: Bool
    @State private var isConfirmingExitPreview = false
    @State private var selection: Tab = .cards
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: Hashable {
        case cards, discover, live, feed, profile
    }

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isGuest = GuestPreviewConfig.isRequested
        // The UI-test harness and guest preview both ride the local data path;
        // only guest preview gets the preview badge and isolated defaults.
        let bootsLocal = isGuest || arguments.contains("UITEST_LOCAL")
        _store = State(initialValue: CardexStore(mode: bootsLocal ? .local : .beta, isGuestPreview: isGuest))
        _isGuestPreview = State(initialValue: isGuest)
    }

    var body: some View {
        Group {
            if store.mode == .local {
                content
            } else {
                betaContent
            }
        }
        .environment(store)
        .preferredColorScheme(.dark)
        .animation(Theme.gentle, value: store.hasCompletedOnboarding)
        .task(id: auth.user?.id) {
            store.attach(auth: auth)
            if let user = auth.user {
                await store.connect(user: user)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.mode == .beta, auth.user != nil {
                Task { await store.refresh() }
            }
        }
        .alert("Cardex", isPresented: Binding(
            get: { store.betaError != nil },
            set: { if !$0 { store.betaError = nil } },
        )) {
            Button("OK") { store.betaError = nil }
        } message: {
            Text(store.betaError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .guestPreviewExit)) { _ in
            exitGuestPreview()
        }
    }

    // MARK: - Guest preview (development only — see GuestPreviewConfig)

    /// Swaps in a guest store: local sample data, isolated defaults, no auth.
    /// Guarded by `isAvailable`, which is false in release builds.
    private func enterGuestPreview() {
        guard GuestPreviewConfig.isAvailable else { return }
        store = CardexStore(mode: .local, isGuestPreview: true)
        isGuestPreview = true
    }

    private func exitGuestPreview() {
        isConfirmingExitPreview = false
        store = CardexStore(mode: .beta)
        isGuestPreview = false
    }

    // MARK: - Local mode (tests / previews)

    @ViewBuilder
    private var content: some View {
        if store.hasCompletedOnboarding {
            tabs
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }

    // MARK: - Beta mode

    @ViewBuilder
    private var betaContent: some View {
        if auth.isRestoringSession {
            splash(message: nil)
        } else if auth.user == nil {
            let guestAction: (() -> Void)? = GuestPreviewConfig.isAvailable ? { enterGuestPreview() } : nil
            SignInGateView(onContinueAsGuest: guestAction)
        } else if case .offline(let message) = store.syncPhase, store.connections.isEmpty, store.rooms.isEmpty {
            // Nothing cached and the backend is unreachable — offer a retry.
            offlineView(message)
        } else if case .connecting = store.syncPhase, store.connections.isEmpty, store.rooms.isEmpty {
            splash(message: "Connecting to Cardex…")
        } else if !store.hasCompletedOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            tabs
                .overlay(alignment: .top) {
                    if case .offline(let message) = store.syncPhase {
                        reconnectBanner(message)
                    }
                }
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            CardsHomeView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack.fill") }
                .tag(Tab.cards)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(Tab.discover)

            LiveView()
                .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }
                .tag(Tab.live)

            FeedView()
                .tabItem { Label("Feed", systemImage: "square.text.square.fill") }
                .tag(Tab.feed)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(Theme.accent)
        .overlay(alignment: .bottom) {
            if isGuestPreview { previewBadge }
        }
    }

    /// Persistent, unmissable marker that the session is a local preview and
    /// not a real Cardex account. Tapping it offers to exit.
    private var previewBadge: some View {
        Button { isConfirmingExitPreview = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Preview Mode · local data only")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(0.92), in: .capsule)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
        .padding(.bottom, 58)
        .confirmationDialog(
            "Exit Preview Mode?",
            isPresented: $isConfirmingExitPreview,
            titleVisibility: .visible,
        ) {
            Button("Exit to Sign In") { exitGuestPreview() }
            Button("Keep Exploring", role: .cancel) {}
        } message: {
            Text("Preview mode uses local sample data only. Exiting returns you to the sign-in screen.")
        }
    }

    private func splash(message: String?) -> some View {
        VStack(spacing: 14) {
            Text("Cardex")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            ProgressView()
                .tint(Theme.accent)
            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private func offlineView(_ message: String) -> some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "Cardex", caption: "Can't reach the network right now.")

            VStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textSecondary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .panel()
            .padding(.horizontal, Theme.margin)

            Button {
                Task {
                    if let user = auth.user {
                        await store.connect(user: user)
                    } else {
                        await store.refresh()
                    }
                }
            } label: {
                PrimaryButtonLabel(title: "Try Again", symbol: "arrow.clockwise")
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private func reconnectBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.red.opacity(0.9), in: .capsule)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ContentView()
}

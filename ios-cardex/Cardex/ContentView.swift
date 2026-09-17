import SwiftUI

/// Root shell: onboarding on first run, then the five-tab wallet.
struct ContentView: View {
    @State private var store = CardexStore()
    @State private var selection: Tab = .cards

    enum Tab: Hashable {
        case cards, discover, live, feed, profile
    }

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
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
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(store)
        .preferredColorScheme(.dark)
        .animation(Theme.gentle, value: store.hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}

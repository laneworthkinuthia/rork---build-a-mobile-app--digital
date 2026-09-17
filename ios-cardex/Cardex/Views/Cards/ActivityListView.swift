import SwiftUI

/// Full activity history pushed from the Cards home.
struct ActivityListView: View {
    @Environment(CardexStore.self) private var store
    @Binding var path: [CardsRoute]

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.activity.isEmpty {
                        EmptyStateView(
                            symbol: "clock",
                            title: "Nothing yet",
                            message: "Exchanges, requests and room activity land here."
                        )
                    } else {
                        ForEach(store.activity) { item in
                            ActivityRow(item: item) {
                                if item.kind == .accessRequest {
                                    path.append(.requests)
                                } else if let connection = store.connection(for: item.card.id) {
                                    path.append(.connection(connection.id))
                                }
                            }
                            .panel()
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }
}

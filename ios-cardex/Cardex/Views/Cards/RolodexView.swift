import SwiftUI

/// Your network: everyone you've exchanged cards or connected with,
/// searchable and sortable.
struct RolodexView: View {
    @Environment(CardexStore.self) private var store
    @Binding var path: [CardsRoute]
    @State private var query = ""
    @State private var favoritesOnly = false

    private var results: [Connection] {
        let base = store.filteredConnections(query: query)
        return favoritesOnly ? base.filter(\.isFavorite) : base
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    filterBar

                    if results.isEmpty {
                        EmptyStateView(
                            symbol: "person.2.slash",
                            title: "No connections yet",
                            message: query.isEmpty
                                ? "Everyone you exchange or connect with lands here — your whole network in one place."
                                : "Nothing matches \"\(query)\"."
                        )
                    } else {
                        ForEach(results) { connection in
                            Button {
                                path.append(.connection(connection.id))
                            } label: {
                                ConnectionRow(connection: connection)
                            }
                            .buttonStyle(.pressable)
                            .contextMenu {
                                Button {
                                    store.toggleFavorite(connection.id)
                                } label: {
                                    Label(
                                        connection.isFavorite ? "Remove favourite" : "Favourite",
                                        systemImage: connection.isFavorite ? "star.slash" : "star"
                                    )
                                }
                                Button(role: .destructive) {
                                    store.removeConnection(connection.id)
                                } label: {
                                    Label("Remove card", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $query, prompt: "Search name, company, industry")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: Binding(
                        get: { store.rolodexSort },
                        set: { store.rolodexSort = $0 }
                    )) {
                        ForEach(CardexStore.RolodexSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(Theme.snappy) { favoritesOnly.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Favourites")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(favoritesOnly ? .white : Theme.textSecondary)
                .padding(.horizontal, 13)
                .frame(height: 33)
                .background(favoritesOnly ? Theme.accent : Theme.surface, in: .capsule)
            }
            .buttonStyle(.pressable)

            Text("\(results.count) connections")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }
}

import SwiftUI

/// Live tab: everyone currently visible in the room you are in, with their
/// 24-hour updates reachable straight from the avatar.
struct LiveView: View {
    @Environment(CardexStore.self) private var store
    @State private var storyStartIndex: Int?
    @State private var isShowingExchange = false
    @State private var isShowingModeSheet = false
    @State private var isComposingStory = false
    @State private var isShowingRoomSwitcher = false
    @State private var previewCard: BusinessCard?

    private var ringCards: [BusinessCard] { store.storyRing }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                // Re-evaluates periodically so 24-hour stories disappear the
                // moment they expire instead of lingering until the next
                // navigation re-render.
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if store.visibility == .dark {
                        darkState
                    } else if let room = store.currentRoom {
                        content(room: room)
                    } else {
                        noRoomState
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: Binding(
                get: { storyStartIndex.map { StoryRoute(index: $0) } },
                set: { storyStartIndex = $0?.index }
            )) { route in
                StoryViewer(cards: ringCards, startIndex: route.index)
            }
            .fullScreenCover(isPresented: $isShowingExchange) {
                ExchangeView()
            }
            .sheet(isPresented: $isShowingModeSheet) {
                VisibilitySheet()
            }
            .sheet(item: $previewCard) { card in
                CardPreviewSheet(card: card)
            }
            .sheet(isPresented: $isComposingStory) {
                ComposeStorySheet()
            }
            .sheet(isPresented: $isShowingRoomSwitcher) {
                RoomSwitcherSheet()
            }
        }
    }

    @ViewBuilder
    private func content(room: Room) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: "Live", caption: "People in your room, right now.") {
                    CircleIconButton(symbol: store.visibility.symbol, tint: store.visibility.tint) {
                        isShowingModeSheet = true
                    }
                }

                roomBanner(room)

                if !ringCards.isEmpty || store.owner.hasActiveStories {
                    storyStrip
                }

                SectionHeader(title: "People Live Now") {
                    Text("\(store.liveInRoom.count)")
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }

                if store.liveInRoom.isEmpty {
                    EmptyStateView(
                        symbol: "person.2.slash",
                        title: "Quiet in here",
                        message: "Nobody else is live in this room yet. Check back in a moment."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.liveInRoom) { card in
                            PersonRow(
                                card: card,
                                state: rowState(for: card),
                                onAvatarTap: card.hasActiveStories ? { openStories(for: card) } : nil
                            ) {
                                store.requestConnection(with: card)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            .onTapGesture { previewCard = card }
                        }
                    }
                    .padding(.horizontal, Theme.margin)
                }
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingExchange = true
            } label: {
                PrimaryButtonLabel(title: "Tap to Exchange", symbol: "qrcode.viewfinder")
                    .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 8)
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 6)
        }
    }

    private func roomBanner(_ room: Room) -> some View {
        Button {
            isShowingRoomSwitcher = true
        } label: {
            Color(Theme.surface)
                .frame(height: 140)
                .overlay {
                    CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                }
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.85), .black.opacity(0.25)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(room.name)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            if store.isRemote(room) {
                                TagPill(text: "Remote", symbol: "video.fill", tint: Theme.accent)
                                    .background(.ultraThinMaterial, in: .capsule)
                            }
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 11))
                            Text("\(room.venue) · \(room.city)").font(.system(size: 13))
                        }
                        .foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: 5) {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6)
                            Text("\(room.liveCount) people live")
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(18)
                }
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Switch room")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(14)
                }
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 0.6)
                }
                .padding(.horizontal, Theme.margin)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Switch room")
    }

    private var storyStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                yourStoryTile

                ForEach(Array(ringCards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        storyStartIndex = index
                    } label: {
                        VStack(spacing: 7) {
                            StoryAvatar(card: card, size: 66, isLive: true)
                            Text(card.firstName)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(card.name), view recent updates")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Theme.margin, for: .scrollContent)
    }

    /// Instagram-style "your story" tile that opens the composer.
    private var yourStoryTile: some View {
        Button {
            isComposingStory = true
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(card: store.owner, size: 66)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(Theme.hairline, lineWidth: 1)
                        }

                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.accent, in: .circle)
                        .overlay { Circle().strokeBorder(Theme.canvas, lineWidth: 2.5) }
                }
                Text("Your story")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Add to your story")
    }

    private var noRoomState: some View {
        VStack(spacing: 20) {
            ScreenHeader(title: "Live", caption: "People in your room, right now.")
            EmptyStateView(
                symbol: "door.left.hand.closed",
                title: "You're not in a room",
                message: "Join a room from Discover to see who is networking there."
            )
            Spacer(minLength: 0)
        }
    }

    private var darkState: some View {
        VStack(spacing: 20) {
            ScreenHeader(title: "Live", caption: "People in your room, right now.") {
                CircleIconButton(symbol: "moon.fill", tint: Theme.textSecondary) {
                    isShowingModeSheet = true
                }
            }

            VStack(spacing: 14) {
                EmptyStateView(
                    symbol: "moon.stars",
                    title: "You're in Dark mode",
                    message: "Nobody can see you and rooms stay hidden. You can still exchange cards face to face."
                )

                Button {
                    isShowingModeSheet = true
                } label: {
                    PrimaryButtonLabel(title: "Go Live", symbol: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 40)
            }

            Spacer(minLength: 0)
        }
    }

    private func rowState(for card: BusinessCard) -> PersonRow.ConnectState {
        if store.isConnected(card) { return .connected }
        if store.isPending(card) { return .pending }
        return .connect
    }

    private func openStories(for card: BusinessCard) {
        guard let index = ringCards.firstIndex(where: { $0.id == card.id }) else { return }
        storyStartIndex = index
    }
}

/// Identifiable wrapper so the story viewer can be presented from an index.
private struct StoryRoute: Identifiable {
    let index: Int
    var id: Int { index }
}

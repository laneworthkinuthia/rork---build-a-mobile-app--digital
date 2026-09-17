import Combine
import SwiftUI

/// Full-screen viewer for 24-hour photo updates, advancing automatically
/// with tap-to-skip on either edge.
struct StoryViewer: View {
    @Environment(\.dismiss) private var dismiss

    let cards: [BusinessCard]
    @State private var cardIndex: Int
    @State private var storyIndex = 0
    @State private var progress: Double = 0

    private let tick: TimeInterval = 0.02
    private let duration: TimeInterval = 5

    init(cards: [BusinessCard], startIndex: Int) {
        self.cards = cards
        self._cardIndex = State(initialValue: min(max(0, startIndex), max(0, cards.count - 1)))
    }

    private var card: BusinessCard? {
        guard cards.indices.contains(cardIndex) else { return nil }
        return cards[cardIndex]
    }

    private var stories: [StoryUpdate] { card?.activeStories ?? [] }

    private var story: StoryUpdate? {
        guard stories.indices.contains(storyIndex) else { return nil }
        return stories[storyIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let card, let story {
                Color.black
                    .overlay {
                        CardPhoto(imageName: story.imageName, monogram: card.monogram, palette: card.palette, photoData: story.imageData)
                    }
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.7), .clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBars
                    header(card: card, story: story)
                    Spacer(minLength: 0)
                    caption(story: story)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)

                HStack(spacing: 0) {
                    tapZone { back() }
                    tapZone { advance() }
                }
                .ignoresSafeArea()
            } else {
                EmptyStateView(
                    symbol: "photo.on.rectangle",
                    title: "No updates",
                    message: "This person has nothing posted in the last 24 hours."
                )
            }
        }
        .statusBarHidden()
        .onReceive(Timer.publish(every: tick, on: .main, in: .common).autoconnect()) { _ in
            guard story != nil else { return }
            progress += tick / duration
            if progress >= 1 { advance() }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 60 { dismiss() }
                }
        )
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(Array(stories.enumerated()), id: \.element.id) { index, _ in
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(.white)
                            .frame(width: geometry.size.width * fill(for: index))
                    }
                }
                .frame(height: 2.5)
            }
        }
        .padding(.top, 10)
    }

    private func fill(for index: Int) -> Double {
        if index < storyIndex { return 1 }
        if index == storyIndex { return min(1, progress) }
        return 0
    }

    private func header(card: BusinessCard, story: StoryUpdate) -> some View {
        HStack(spacing: 11) {
            Avatar(card: card, size: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(card.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(story.postedAt.shortRelativeLabel) · \(story.remainingLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
        .padding(.top, 14)
    }

    private func caption(story: StoryUpdate) -> some View {
        Text(story.caption)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func tapZone(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Color.clear.contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        progress = 0
        if storyIndex + 1 < stories.count {
            storyIndex += 1
        } else if cardIndex + 1 < cards.count {
            cardIndex += 1
            storyIndex = 0
        } else {
            dismiss()
        }
    }

    private func back() {
        progress = 0
        if storyIndex > 0 {
            storyIndex -= 1
        } else if cardIndex > 0 {
            cardIndex -= 1
            storyIndex = 0
        }
    }
}

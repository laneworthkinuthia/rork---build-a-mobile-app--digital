import SwiftUI

/// Feed tab: the activity layer. Professional updates from people whose cards
/// you carry, always secondary to the card itself.
struct FeedView: View {
    @Environment(CardexStore.self) private var store
    @State private var isComposing = false
    @State private var storyCards: [BusinessCard] = []
    @State private var isShowingStories = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ScreenHeader(title: "Feed", caption: "Updates from people you've met.") {
                            CircleIconButton(symbol: "square.and.pencil") { isComposing = true }
                        }

                        if store.posts.isEmpty {
                            EmptyStateView(
                                symbol: "square.stack",
                                title: "Nothing posted yet",
                                message: "Share an update and your connections will see it here."
                            )
                        } else {
                            ForEach(store.posts) { post in
                                FeedPostCard(post: post) {
                                    store.toggleApplause(post.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } onAvatarTap: {
                                    guard post.author.hasActiveStories else { return }
                                    storyCards = [post.author]
                                    isShowingStories = true
                                }
                                .padding(.horizontal, Theme.margin)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isComposing) {
                ComposePostSheet()
            }
            .fullScreenCover(isPresented: $isShowingStories) {
                StoryViewer(cards: storyCards, startIndex: 0)
            }
        }
    }
}

/// A single post: author card strip, body, optional photo and reactions.
struct FeedPostCard: View {
    let post: FeedPost
    let onApplaud: () -> Void
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Button(action: onAvatarTap) {
                    StoryAvatar(card: post.author, size: 44)
                }
                .buttonStyle(.pressable)
                .disabled(!post.author.hasActiveStories)

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(post.author.title), \(post.author.company)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(post.postedAt.shortRelativeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    TagPill(text: post.audience.title, symbol: post.audience.symbol)
                }
            }

            Text(post.body)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let imageName = post.imageName {
                Color(Theme.surfaceHigh)
                    .frame(height: 200)
                    .overlay {
                        CardPhoto(
                            imageName: imageName,
                            monogram: post.author.monogram,
                            palette: post.author.palette
                        )
                    }
                    .clipShape(.rect(cornerRadius: 16))
            }

            HStack(spacing: 18) {
                Button(action: onApplaud) {
                    HStack(spacing: 6) {
                        Image(systemName: post.hasApplauded ? "hands.clap.fill" : "hands.clap")
                            .font(.system(size: 14))
                        Text("\(post.applauds)")
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundStyle(post.hasApplauded ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.pressable)

                HStack(spacing: 6) {
                    Image(systemName: "bubble.left").font(.system(size: 14))
                    Text("\(post.comments)")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(15)
        .panel(radius: 20)
    }
}

/// Compose sheet for a new post with audience control.
struct ComposePostSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var body_ = ""
    @State private var audience: FeedPost.Audience = .connections
    @State private var attachment: String?

    private let attachments = ["warehouse_networking_event", "founders_breakfast_cafe", "design_studio_meetup", "rooftop_gathering_dusk"]

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 11) {
                            Avatar(card: store.owner, size: 42)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(store.owner.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(store.owner.title)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }

                        TextEditor(text: $body_)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(height: 130)
                            .padding(10)
                            .panel()
                            .overlay(alignment: .topLeading) {
                                if body_.isEmpty {
                                    Text("Share an update, a win, or what you're working on")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }

                        Text("Photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)

                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(attachments, id: \.self) { name in
                                    Button {
                                        withAnimation(Theme.snappy) {
                                            attachment = attachment == name ? nil : name
                                        }
                                    } label: {
                                        Color(Theme.surfaceHigh)
                                            .frame(width: 92, height: 68)
                                            .overlay {
                                                CardPhoto(imageName: name, monogram: "P", palette: .graphite)
                                            }
                                            .clipShape(.rect(cornerRadius: 12))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        attachment == name ? Theme.accent : Theme.hairline,
                                                        lineWidth: attachment == name ? 2 : 0.6
                                                    )
                                            }
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)

                        Text("Who can see this")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(FeedPost.Audience.allCases) { option in
                                Button {
                                    withAnimation(Theme.snappy) { audience = option }
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: option.symbol).font(.system(size: 12))
                                        Text(option.title).font(.system(size: 14, weight: .medium))
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(audience == option ? Theme.accent : Theme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .frame(height: 42)
                                    .background(
                                        audience == option ? Theme.accentSoft : Theme.surface,
                                        in: .rect(cornerRadius: 12)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                audience == option ? Theme.accent.opacity(0.5) : Theme.hairline,
                                                lineWidth: 0.8
                                            )
                                    }
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                    .padding(Theme.margin)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        store.publishPost(
                            body: body_.trimmingCharacters(in: .whitespacesAndNewlines),
                            audience: audience,
                            imageName: attachment
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }
}

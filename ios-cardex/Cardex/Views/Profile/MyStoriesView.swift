import SwiftUI

/// The user's own 24-hour photo updates, with a simple composer.
struct MyStoriesView: View {
    @Environment(CardexStore.self) private var store
    @State private var isComposing = false
    @State private var isViewing = false

    private var stories: [StoryUpdate] { store.owner.activeStories }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if stories.isEmpty {
                        EmptyStateView(
                            symbol: "photo.stack",
                            title: "No updates live",
                            message: "Post a photo and people in your room can tap your card to see it for 24 hours."
                        )
                    } else {
                        Button { isViewing = true } label: {
                            HStack(spacing: 12) {
                                StoryAvatar(card: store.owner, size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Preview your updates")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(stories.count) live right now")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(14)
                            .panel()
                        }
                        .buttonStyle(.pressable)

                        ForEach(stories) { story in
                            VStack(alignment: .leading, spacing: 0) {
                                Color(Theme.surfaceHigh)
                                    .frame(height: 180)
                                    .overlay {
                                        CardPhoto(
                                            imageName: story.imageName,
                                            monogram: store.owner.monogram,
                                            palette: store.owner.palette
                                        )
                                    }
                                    .clipShape(.rect(cornerRadius: 16))

                                HStack(spacing: 8) {
                                    Text(story.caption)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer(minLength: 0)
                                    TagPill(text: story.remainingLabel, symbol: "clock", tint: Theme.warning)
                                }
                                .padding(.top, 12)
                            }
                            .padding(12)
                            .panel(radius: 20)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("My Updates")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isComposing = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isComposing) {
            ComposeStorySheet()
        }
        .fullScreenCover(isPresented: $isViewing) {
            StoryViewer(cards: [store.owner], startIndex: 0)
        }
    }
}

/// Composer for a 24-hour update.
struct ComposeStorySheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var caption = ""
    @State private var selection = "warehouse_networking_event"
    @State private var pickedData: Data?
    @State private var isShowingPhotoSources = false

    private let options = ["warehouse_networking_event", "founders_breakfast_cafe", "design_studio_meetup", "rooftop_gathering_dusk"]

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color(Theme.surfaceHigh)
                            .frame(height: 230)
                            .overlay {
                                CardPhoto(
                                    imageName: pickedData == nil ? selection : "",
                                    monogram: store.owner.monogram,
                                    palette: store.owner.palette,
                                    photoData: pickedData
                                )
                            }
                            .clipShape(.rect(cornerRadius: 18))

                        HStack(spacing: 10) {
                            Button {
                                isShowingPhotoSources = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.pressable)

                            Button {
                                isShowingPhotoSources = true
                            } label: {
                                Label("Upload", systemImage: "photo.on.rectangle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(Theme.surfaceHigh, in: .rect(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 0.6)
                                    }
                            }
                            .buttonStyle(.pressable)
                        }

                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(options, id: \.self) { name in
                                    Button {
                                        withAnimation(Theme.snappy) { selection = name; pickedData = nil }
                                    } label: {
                                        Color(Theme.surfaceHigh)
                                            .frame(width: 84, height: 62)
                                            .overlay {
                                                CardPhoto(imageName: name, monogram: "P", palette: .graphite)
                                            }
                                            .clipShape(.rect(cornerRadius: 11))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 11)
                                                    .strokeBorder(
                                                        selection == name ? Theme.accent : Theme.hairline,
                                                        lineWidth: selection == name ? 2 : 0.6
                                                    )
                                            }
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)

                        EditorField(label: "Caption", text: $caption, placeholder: "Say something about it")

                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                            Text("Disappears after 24 hours.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .padding(Theme.margin)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        store.postStory(
                            imageName: selection,
                            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                            imageData: pickedData
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pickedData == nil)
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
        .sheet(isPresented: $isShowingPhotoSources) {
            PhotoSourceSheet(showsAvatarOption: false, onPhoto: { data in
                withAnimation(Theme.snappy) { pickedData = data }
            })
        }
    }
}

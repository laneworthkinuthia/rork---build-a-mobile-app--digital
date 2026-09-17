import SwiftUI

/// Card editor with a live preview above the controls, so every change is
/// visible on the card as you make it.
struct CardEditorView: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BusinessCard = SampleData.makeOwner()
    @State private var isFlipped = false
    @State private var section: Section = .identity
    @State private var isShowingPhotoSources = false

    private enum Section: String, CaseIterable, Identifiable {
        case identity, design, contact
        var id: String { rawValue }
        var title: String {
            switch self {
            case .identity: "Identity"
            case .design: "Design"
            case .contact: "Contact"
            }
        }
    }

    private let photoOptions = [
        "woman_business_portrait", "woman_curly_hair_portrait", "latina_woman_portrait",
        "professional_editorial_portrait", "venture_capital_investor_woman", "man_cto_portrait"
    ]

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(spacing: 18) {
                    FlippableCard(isFlipped: $isFlipped) {
                        BusinessCardFront(card: draft)
                    } back: {
                        BusinessCardBack(card: draft, visibleDetails: draft.details, lockedDetails: [])
                    }
                    .frame(height: 280)
                    .padding(.horizontal, Theme.margin)
                    .onTapGesture { isFlipped.toggle() }

                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.margin)

                    switch section {
                    case .identity: identitySection
                    case .design: designSection
                    case .contact: contactSection
                    }
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Edit Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.updateOwner { $0 = draft }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear { draft = store.owner }
        .sheet(isPresented: $isShowingPhotoSources) {
            PhotoSourceSheet(
                onPhoto: { data in withAnimation(Theme.snappy) { draft.photoData = data; draft.photoName = "" } },
                onAvatar: { withAnimation(Theme.snappy) { draft.photoName = ""; draft.photoData = nil } }
            )
        }
    }

    private var identitySection: some View {
        VStack(spacing: 12) {
            EditorField(label: "Full name", text: $draft.name)
            EditorField(label: "Title", text: $draft.title)
            EditorField(label: "Company", text: $draft.company)
            EditorField(label: "Industry", text: $draft.industry)
            EditorField(label: "Tagline", text: $draft.tagline)
            EditorField(label: "Location", text: $draft.location)
        }
        .padding(.horizontal, Theme.margin)
    }

    private var designSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Card finish")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(CardPalette.allCases) { palette in
                        Button {
                            withAnimation(Theme.snappy) { draft.palette = palette }
                        } label: {
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(palette.base)
                                    .frame(height: 44)
                                Text(palette.displayName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        draft.palette == palette ? Theme.textPrimary : Theme.textSecondary
                                    )
                            }
                            .padding(8)
                            .background(
                                draft.palette == palette ? Theme.accentSoft : Theme.surface,
                                in: .rect(cornerRadius: 14)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        draft.palette == palette ? Theme.accent : Theme.hairline,
                                        lineWidth: draft.palette == palette ? 1.5 : 0.6
                                    )
                            }
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Photo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                    Button {
                        isShowingPhotoSources = true
                    } label: {
                        Text("Camera · Upload · Avatar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.pressable)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 10)], spacing: 10) {
                    Button {
                        isShowingPhotoSources = true
                    } label: {
                        Color(Theme.surfaceHigh)
                            .frame(width: 62, height: 62)
                            .overlay {
                                CardPhoto(imageName: "", monogram: draft.monogram, palette: draft.palette, photoData: draft.photoData)
                            }
                            .clipShape(.circle)
                            .overlay {
                                Circle().strokeBorder(draft.isAvatarOnly ? Theme.accent : Theme.hairline, lineWidth: draft.isAvatarOnly ? 2.2 : 0.6)
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Create an avatar")

                    ForEach(photoOptions, id: \.self) { name in
                        Button {
                            withAnimation(Theme.snappy) { draft.photoName = name; draft.photoData = nil }
                        } label: {
                            Color(Theme.surfaceHigh)
                                .frame(width: 62, height: 62)
                                .overlay {
                                    CardPhoto(imageName: name, monogram: draft.monogram, palette: draft.palette)
                                }
                                .clipShape(.circle)
                                .overlay {
                                    Circle().strokeBorder(
                                        draft.photoName == name && draft.photoData == nil ? Theme.accent : Theme.hairline,
                                        lineWidth: draft.photoName == name && draft.photoData == nil ? 2.2 : 0.6
                                    )
                                }
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.margin)
    }

    private var contactSection: some View {
        VStack(spacing: 10) {
            ForEach($draft.details) { $detail in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 9) {
                        Image(systemName: detail.kind.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Theme.surfaceHigh, in: .rect(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(detail.kind.label)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                            TextField(detail.kind.label, text: $detail.value)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    Picker("Visible to", selection: $detail.tier) {
                        ForEach(AccessTier.allCases) { tier in
                            Text(tier.title).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(13)
                .panel()
            }

            Text("Trusted details stay hidden until you approve a request.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, Theme.margin)
    }
}

/// Labelled text field used across the editor and onboarding.
struct EditorField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)

            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .panel()
    }
}

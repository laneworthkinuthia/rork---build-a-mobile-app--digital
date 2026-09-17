import SwiftUI

/// First-run flow: identity, contact details, card design and default privacy.
struct OnboardingView: View {
    @Environment(CardexStore.self) private var store

    @State private var step = 0
    @State private var draft: BusinessCard = SampleData.makeOwner()
    @State private var mode: VisibilityMode = .live
    @State private var isShowingPhotoSources = false

    private let totalSteps = 5

    private let photoOptions = [
        "woman_business_portrait", "woman_curly_hair_portrait", "latina_woman_portrait",
        "professional_editorial_portrait", "venture_capital_investor_woman", "man_cto_portrait"
    ]

    var body: some View {
        ZStack {
            CanvasBackground()

            VStack(spacing: 0) {
                progressBar

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    photoStep.tag(1)
                    identityStep.tag(2)
                    designStep.tag(3)
                    privacyStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Theme.gentle, value: step)

                footer
            }
        }
        .onAppear { draft = store.owner }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.accent : Theme.surfaceHigh)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .animation(Theme.snappy, value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 30)

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(CardPalette.allCases[index].base)
                            .frame(width: 210, height: 128)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.8)
                            }
                            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                            .rotationEffect(.degrees(Double(index - 1) * 7))
                            .offset(y: CGFloat(index) * -14)
                    }
                }
                .padding(.bottom, 12)

                VStack(spacing: 10) {
                    Text("Your card,\nalways on you.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Cardex is a digital wallet for the people you meet. Exchange a card in a tap, keep every detail in one place, and decide exactly what each person can see.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, Theme.margin)
        }
        .scrollIndicators(.hidden)
    }

    private var photoStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(title: "Pick your photo", caption: "Take a picture, upload one, or create an avatar.")

                Button {
                    isShowingPhotoSources = true
                } label: {
                    Color(Theme.surfaceHigh)
                        .frame(width: 150, height: 150)
                        .overlay {
                            CardPhoto(imageName: draft.photoName, monogram: draft.monogram, palette: draft.palette, photoData: draft.photoData)
                        }
                        .clipShape(.circle)
                        .overlay { Circle().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 2) }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Theme.accent, in: .circle)
                                .overlay { Circle().strokeBorder(Theme.canvas, lineWidth: 3) }
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Change profile photo")

                HStack(spacing: 10) {
                    photoSourceButton(symbol: "camera.fill", title: "Take Photo") {
                        isShowingPhotoSources = true
                    }
                    photoSourceButton(symbol: "photo.on.rectangle", title: "Upload") {
                        isShowingPhotoSources = true
                    }
                    photoSourceButton(symbol: "person.crop.artframe", title: "Avatar") {
                        draft.photoName = ""
                        draft.photoData = nil
                    }
                }
                .padding(.horizontal, Theme.margin)

                VStack(spacing: 10) {
                    Text("OR PICK A SAMPLE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textTertiary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 12)], spacing: 12) {
                        ForEach(photoOptions, id: \.self) { name in
                            Button {
                                withAnimation(Theme.snappy) { draft.photoName = name; draft.photoData = nil }
                            } label: {
                                Color(Theme.surfaceHigh)
                                    .frame(width: 70, height: 70)
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
                    .padding(.horizontal, Theme.margin)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isShowingPhotoSources) {
            PhotoSourceSheet(
                onPhoto: { data in withAnimation(Theme.snappy) { draft.photoData = data; draft.photoName = "" } },
                onAvatar: { withAnimation(Theme.snappy) { draft.photoName = ""; draft.photoData = nil } }
            )
        }
    }

    private func photoSourceButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Theme.accent.opacity(0.14), in: .circle)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .panel()
        }
        .buttonStyle(.pressable)
    }

    private var identityStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                stepHeader(
                    title: "Who are you?",
                    caption: "The essentials that go on the front of your card."
                )

                EditorField(label: "Full name", text: $draft.name)
                EditorField(label: "Profession", text: $draft.title)
                EditorField(label: "Company", text: $draft.company)
                EditorField(label: "Industry", text: $draft.industry)
                EditorField(label: "Tagline", text: $draft.tagline)
                EditorField(label: "Location", text: $draft.location)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var designStep: some View {
        ScrollView {
            VStack(spacing: 18) {
                stepHeader(title: "Design your card", caption: "Choose a finish. You can change it any time.")

                BusinessCardFront(card: draft)
                    .frame(height: 230)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(CardPalette.allCases) { palette in
                        Button {
                            withAnimation(Theme.snappy) { draft.palette = palette }
                        } label: {
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(palette.base)
                                    .frame(height: 40)
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
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var privacyStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                stepHeader(title: "How visible are you?", caption: "Pick a starting mode. Switch whenever you like.")

                ForEach(VisibilityMode.allCases) { option in
                    Button {
                        withAnimation(Theme.snappy) { mode = option }
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(option.tint)
                                .frame(width: 42, height: 42)
                                .background(option.tint.opacity(0.15), in: .circle)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(option.caption)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19))
                                .foregroundStyle(mode == option ? Theme.accent : Theme.textTertiary)
                        }
                        .padding(14)
                        .background(
                            mode == option ? Theme.accentSoft : Theme.surface,
                            in: .rect(cornerRadius: Theme.rowRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.rowRadius)
                                .strokeBorder(
                                    mode == option ? Theme.accent.opacity(0.45) : Theme.hairline,
                                    lineWidth: 0.8
                                )
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func stepHeader(title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(caption)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    withAnimation(Theme.gentle) { step -= 1 }
                } label: {
                    SecondaryButtonLabel(title: "Back")
                }
                .buttonStyle(.pressable)
                .frame(width: 110)
            }

            Button {
                if step < totalSteps - 1 {
                    withAnimation(Theme.gentle) { step += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    finish()
                }
            } label: {
                PrimaryButtonLabel(
                    title: step == 0 ? "Create My Card" : (step == totalSteps - 1 ? "Finish" : "Continue"),
                    symbol: step == totalSteps - 1 ? "checkmark" : nil
                )
            }
            .buttonStyle(.pressable)
            .disabled(step == 2 && draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func finish() {
        draft.visibility = mode
        draft.monogram = initials(from: draft.name)
        store.updateOwner { $0 = draft }
        store.completeOnboarding()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "C" : letters.joined().uppercased()
    }
}

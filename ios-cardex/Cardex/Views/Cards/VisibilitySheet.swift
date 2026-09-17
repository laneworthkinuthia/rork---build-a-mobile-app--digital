import SwiftUI

/// Picker for the four visibility modes.
struct VisibilitySheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(VisibilityMode.allCases) { mode in
                            Button {
                                withAnimation(Theme.snappy) { store.setVisibility(mode) }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                modeRow(mode)
                            }
                            .buttonStyle(.pressable)
                        }

                        Text("Dark mode keeps you completely invisible. You can still exchange cards face to face with a code.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    .padding(Theme.margin)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func modeRow(_ mode: VisibilityMode) -> some View {
        let isActive = store.visibility == mode

        return HStack(spacing: 14) {
            Image(systemName: mode.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(mode.tint)
                .frame(width: 44, height: 44)
                .background(mode.tint.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(mode.caption)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isActive ? Theme.accent : Theme.textTertiary)
        }
        .padding(14)
        .background(isActive ? Theme.accentSoft : Theme.surface, in: .rect(cornerRadius: Theme.rowRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rowRadius)
                .strokeBorder(isActive ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 0.8)
        }
    }
}

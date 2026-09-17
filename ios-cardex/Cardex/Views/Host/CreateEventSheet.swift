import SwiftUI

/// Business accounts create an event here: details, entry policy and, for
/// ticketed events, a price.
struct CreateEventSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var venue = ""
    @State private var city = "London, UK"
    @State private var blurb = ""
    @State private var access: Room.Access = .openDoor
    @State private var priceText = ""
    @State private var imageName = "warehouse_networking_event"

    private let imageOptions = [
        "warehouse_networking_event", "founders_breakfast_cafe",
        "design_studio_meetup", "rooftop_gathering_dusk"
    ]

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !venue.trimmingCharacters(in: .whitespaces).isEmpty
            && (access != .ticketed || ticketPrice != nil)
    }

    private var ticketPrice: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed.replacingOccurrences(of: "£", with: "")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        stepTitle

                        EditorField(label: "Event name", text: $name, placeholder: "Shoreditch Founders Night")
                        EditorField(label: "Venue", text: $venue, placeholder: "The Boiler Room")
                        EditorField(label: "City", text: $city)
                        EditorField(label: "Description", text: $blurb, placeholder: "What happens in this room?")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ENTRY")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.4)
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.leading, 4)

                            ForEach([Room.Access.openDoor, .request, .ticketed], id: \.self) { option in
                                entryOption(option)
                            }

                            if access == .ticketed {
                                HStack(spacing: 10) {
                                    Text("£")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                    TextField("15", text: $priceText)
                                        .font(.system(size: 18, weight: .semibold))
                                        .monospacedDigit()
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .panel()
                                .overlay {
                                    RoundedRectangle(cornerRadius: Theme.rowRadius)
                                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 0.8)
                                }
                            }
                        }
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("COVER PHOTO")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.4)
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.leading, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(imageOptions, id: \.self) { option in
                                        Button {
                                            withAnimation(Theme.snappy) { imageName = option }
                                        } label: {
                                            Color(Theme.surfaceHigh)
                                                .frame(width: 130, height: 78)
                                                .overlay { CardPhoto(imageName: option, monogram: "R", palette: .graphite) }
                                                .clipShape(.rect(cornerRadius: 12))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .strokeBorder(
                                                            imageName == option ? Theme.accent : Theme.hairline,
                                                            lineWidth: imageName == option ? 2 : 0.6
                                                        )
                                                }
                                        }
                                        .buttonStyle(.pressable)
                                    }
                                }
                                .padding(.horizontal, Theme.margin)
                            }
                            .contentMargins(.horizontal, -Theme.margin)
                        }
                        .padding(.top, 6)
                    }
                    .padding(Theme.margin)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard canCreate else { return }
                    store.createEvent(
                        name: name.trimmingCharacters(in: .whitespaces),
                        venue: venue.trimmingCharacters(in: .whitespaces),
                        city: city,
                        blurb: blurb.isEmpty ? "A new Cardex event." : blurb,
                        imageName: imageName,
                        access: access,
                        ticketPrice: ticketPrice
                    )
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    PrimaryButtonLabel(title: "Create & Go Live", symbol: "sparkles")
                }
                .buttonStyle(.pressable)
                .disabled(!canCreate)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private var stepTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Create an event")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("You'll host the room, see everyone who joins and approve who gets in.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private func entryOption(_ option: Room.Access) -> some View {
        let isSelected = access == option

        return Button {
            withAnimation(Theme.snappy) { access = option }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background((isSelected ? Theme.accent : Theme.textSecondary).opacity(0.13), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.badge)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(entryCaption(option))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            .padding(12)
            .background(isSelected ? Theme.accentSoft : Theme.surface, in: .rect(cornerRadius: Theme.rowRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.rowRadius)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.4) : Theme.hairline, lineWidth: 0.8)
            }
        }
        .buttonStyle(.pressable)
    }

    private func entryCaption(_ option: Room.Access) -> String {
        switch option {
        case .openDoor: "Anyone can walk in"
        case .request: "You approve every entry request"
        case .ticketed: "People pay a ticket to get in"
        }
    }
}

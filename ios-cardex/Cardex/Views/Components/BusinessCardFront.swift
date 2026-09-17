import SwiftUI

/// The front face of a digital business card — photo backdrop, muted duotone
/// scrim and the person's identity typeset over it.
struct BusinessCardFront: View {
    let card: BusinessCard
    var showsLogo: Bool = true
    var trailingAccessory: AnyView?

    init(card: BusinessCard, showsLogo: Bool = true) {
        self.card = card
        self.showsLogo = showsLogo
        self.trailingAccessory = nil
    }

    init<Accessory: View>(
        card: BusinessCard,
        showsLogo: Bool = true,
        @ViewBuilder trailingAccessory: () -> Accessory
    ) {
        self.card = card
        self.showsLogo = showsLogo
        self.trailingAccessory = AnyView(trailingAccessory())
    }

    var body: some View {
        Color(Theme.surface)
            .overlay {
                CardPhoto(imageName: card.photoName, monogram: card.monogram, palette: card.palette)
            }
            .overlay { card.palette.scrim.allowsHitTesting(false) }
            .overlay { card.palette.vignette.allowsHitTesting(false) }
            .overlay(alignment: .topLeading) { header.padding(22) }
            .overlay(alignment: .bottomLeading) { identity.padding(22) }
            .overlay(alignment: .bottomTrailing) { locationLabel.padding(22) }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
    }

    private var header: some View {
        HStack(alignment: .top) {
            if showsLogo {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.85), .white.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(45))
                        .frame(width: 26, height: 26)

                    Text(card.company.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .frame(maxWidth: 110, alignment: .leading)
                }
            }

            Spacer(minLength: 8)

            if let trailingAccessory {
                trailingAccessory
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(card.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))

            Text(card.company)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.55))

            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: 26, height: 1)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Text(card.tagline.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
                .frame(maxWidth: 190, alignment: .leading)
        }
    }

    private var locationLabel: some View {
        Text(card.location.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.5))
    }
}

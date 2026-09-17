import SwiftUI

/// Bundled or user-picked photo with a graceful monogram fallback.
struct CardPhoto: View {
    let imageName: String
    let monogram: String
    let palette: CardPalette
    var photoData: Data? = nil

    var body: some View {
        if let data = photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
        } else if !imageName.isEmpty, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
        } else {
            palette.base
                .overlay {
                    Text(monogram)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary.opacity(0.7))
                }
                .allowsHitTesting(false)
        }
    }
}

/// Circular avatar used in lists, activity rows and story rings.
struct Avatar: View {
    let card: BusinessCard
    var size: CGFloat = 44

    var body: some View {
        Color(Theme.surfaceHigh)
            .frame(width: size, height: size)
            .overlay {
                CardPhoto(
                    imageName: card.photoName,
                    monogram: card.monogram,
                    palette: card.palette,
                    photoData: card.photoData
                )
            }
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
    }
}

/// Avatar wrapped in a story ring when the person has active 24h updates.
struct StoryAvatar: View {
    let card: BusinessCard
    var size: CGFloat = 64
    var isLive: Bool = false

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [Theme.accent, Color(hex: 0x9C8CFF), Color(hex: 0x5FD3C4), Theme.accent],
            center: .center
        )
    }

    var body: some View {
        Avatar(card: card, size: size)
            .padding(3)
            .overlay {
                if card.hasActiveStories {
                    Circle().strokeBorder(ringGradient, lineWidth: 2.2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isLive {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: size * 0.2, height: size * 0.2)
                        .overlay {
                            Circle().strokeBorder(Theme.canvas, lineWidth: 2)
                        }
                }
            }
    }
}

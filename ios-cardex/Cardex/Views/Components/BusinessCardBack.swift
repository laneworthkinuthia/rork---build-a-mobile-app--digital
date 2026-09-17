import SwiftUI

/// The back face of a card: the contact details you actually reach someone with,
/// plus credentials. Locked rows are redacted until access is granted.
struct BusinessCardBack: View {
    let card: BusinessCard
    let visibleDetails: [ContactDetail]
    let lockedDetails: [ContactDetail]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().overlay(Color.white.opacity(0.1))

            VStack(spacing: 0) {
                ForEach(Array(visibleDetails.enumerated()), id: \.element.id) { index, detail in
                    detailRow(detail, locked: false)
                    if index < visibleDetails.count - 1 || !lockedDetails.isEmpty {
                        Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 44)
                    }
                }

                ForEach(Array(lockedDetails.enumerated()), id: \.element.id) { index, detail in
                    detailRow(detail, locked: true)
                    if index < lockedDetails.count - 1 {
                        Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 44)
                    }
                }
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)

            if !card.credentials.isEmpty {
                Divider().overlay(Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 4) {
                    Text("CREDENTIALS")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.4))
                    ForEach(card.credentials, id: \.self) { credential in
                        Text(credential)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
        .background {
            ZStack {
                card.palette.base
                LinearGradient(
                    colors: [.black.opacity(0.35), .clear],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            }
        }
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(card: card, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(card.title) · \(card.company)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private func detailRow(_ detail: ContactDetail, locked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: locked ? "lock.fill" : detail.kind.symbol)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(locked ? 0.3 : 0.55))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(detail.kind.label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.42))

                if locked {
                    Text(String(repeating: "•", count: min(14, max(8, detail.value.count))))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .blur(radius: 1.4)
                } else {
                    Text(detail.value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }
}

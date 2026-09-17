import SwiftUI

/// Access control: decide exactly which tier each piece of information belongs to.
struct AccessControlView: View {
    @Environment(CardexStore.self) private var store

    private func details(for tier: AccessTier) -> [ContactDetail] {
        store.owner.details.filter { $0.tier == tier }
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(spacing: 16) {
                    Text("You decide what each group can see. Anything marked Trusted stays hidden until you personally approve a request.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.margin)

                    ForEach(AccessTier.allCases) { tier in
                        tierCard(tier)
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Access Control")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }

    private func tierCard(_ tier: AccessTier) -> some View {
        let items = details(for: tier)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol(for: tier))
                    .font(.system(size: 14))
                    .foregroundStyle(tint(for: tier))
                    .frame(width: 34, height: 34)
                    .background(tint(for: tier).opacity(0.15), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tier.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(tier.caption)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            if items.isEmpty {
                Text("Nothing shared at this level.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { detail in
                        HStack(spacing: 10) {
                            Image(systemName: detail.kind.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(detail.kind.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                                Text(detail.value)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Menu {
                                ForEach(AccessTier.allCases) { option in
                                    Button(option.title) { move(detail, to: option) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Move")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Theme.accentSoft, in: .capsule)
                            }
                        }
                        .padding(10)
                        .background(Theme.surfaceHigh, in: .rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(15)
        .panel(radius: 20)
        .padding(.horizontal, Theme.margin)
    }

    private func move(_ detail: ContactDetail, to tier: AccessTier) {
        store.updateOwner { card in
            guard let index = card.details.firstIndex(where: { $0.id == detail.id }) else { return }
            card.details[index].tier = tier
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func symbol(for tier: AccessTier) -> String {
        switch tier {
        case .publicTier: "globe"
        case .connected: "person.2.fill"
        case .trusted: "lock.shield.fill"
        }
    }

    private func tint(for tier: AccessTier) -> Color {
        switch tier {
        case .publicTier: Theme.openDoor
        case .connected: Theme.accent
        case .trusted: Theme.warning
        }
    }
}

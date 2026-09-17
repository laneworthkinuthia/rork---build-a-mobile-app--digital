import SwiftUI

/// The tap-to-exchange moment: show your code, or scan someone else's, and the
/// card lands in both rolodexes.
struct ExchangeView: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .share
    @State private var pulse = false
    @State private var sweep = false
    @State private var matchedCard: BusinessCard?
    @State private var exchangedCard: BusinessCard?

    private enum Mode: String, CaseIterable, Identifiable {
        case share, scan
        var id: String { rawValue }
        var title: String { self == .share ? "My Code" : "Scan" }
    }

    /// People nearby who can be exchanged with in this prototype.
    private var nearby: [BusinessCard] {
        let live = store.liveInRoom.filter { !store.isConnected($0) }
        return live.isEmpty ? store.discoverable.filter { !store.isConnected($0) } : live
    }

    private var payload: String {
        "cardex://card/\(store.owner.id.uuidString)"
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accent.opacity(0.22), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 60)
                .padding(.top, 4)

                Spacer(minLength: 0)

                if mode == .share { shareContent } else { scanContent }

                Spacer(minLength: 0)

                Button { dismiss() } label: {
                    SecondaryButtonLabel(title: "Cancel")
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { pulse = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true }
        }
        .sheet(item: $exchangedCard) { card in
            ExchangeSuccessSheet(card: card)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: .circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 12)
    }

    private var shareContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Scan to connect")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(store.owner.name)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
            }

            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: 290, height: 290)
                        .scaleEffect(pulse ? 1.18 : 0.88)
                        .opacity(pulse ? 0 : 0.8)
                        .animation(
                            .easeOut(duration: 2.2).repeatForever(autoreverses: false).delay(Double(index) * 1.1),
                            value: pulse
                        )
                }

                VStack(spacing: 16) {
                    QRCodeImage(payload: payload, size: 198)
                        .padding(16)
                        .background(.white, in: .rect(cornerRadius: 22))

                    HStack(spacing: 10) {
                        Avatar(card: store.owner, size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(store.owner.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(store.owner.title)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(width: 230)
                    .panel()
                }
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                    .opacity(sweep ? 1 : 0.3)
                Text("Searching nearby...")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var scanContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Point at their code")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Or pick someone detected nearby")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Theme.accent.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [50, 18]))
                    .frame(width: 230, height: 230)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Theme.accent.opacity(0.7), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 210, height: 2)
                    .offset(y: sweep ? 92 : -92)

                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundStyle(Theme.textTertiary)
            }

            if nearby.isEmpty {
                Text("No one nearby to exchange with yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(nearby) { card in
                            Button {
                                let place = store.currentRoom?.name ?? "Cardex"
                                store.exchangeCards(with: card, at: place)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                exchangedCard = card
                            } label: {
                                VStack(spacing: 7) {
                                    Avatar(card: card, size: 52)
                                    Text(card.firstName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Exchange")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.accent)
                                }
                                .frame(width: 84)
                                .padding(.vertical, 12)
                                .panel()
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, Theme.margin, for: .scrollContent)
            }
        }
    }
}

/// Confirmation shown after an exchange lands in the rolodex.
struct ExchangeSuccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: BusinessCard

    var body: some View {
        ZStack {
            CanvasBackground()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 34)

                VStack(spacing: 5) {
                    Text("Cards exchanged")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(card.name) is now in your connections.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }

                BusinessCardFront(card: card)
                    .frame(height: 220)
                    .padding(.horizontal, Theme.margin)

                Spacer(minLength: 0)

                Button { dismiss() } label: {
                    PrimaryButtonLabel(title: "Done")
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.large])
    }
}

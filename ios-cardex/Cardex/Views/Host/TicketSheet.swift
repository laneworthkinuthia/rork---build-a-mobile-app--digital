import SwiftUI

/// Payment sheet for a ticketed event. Confirming runs the purchase through
/// the injected PaymentProcessing service (simulated in development — no real
/// charge, no payment data collected) and steps the user into the room.
struct TicketSheet: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let roomID: UUID
    @State private var isProcessing = false
    @State private var isPurchased = false
    @State private var errorMessage: String?

    private var room: Room? { store.rooms.first { $0.id == roomID } }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if let room {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)

                        // Ticket stub
                        VStack(spacing: 0) {
                            Color(Theme.surfaceHigh)
                                .frame(height: 130)
                                .overlay {
                                    CardPhoto(imageName: room.imageName, monogram: "R", palette: .graphite)
                                }
                                .overlay {
                                    LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top)
                                }
                                .overlay(alignment: .bottomLeading) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(room.name)
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("\(room.venue) · \(room.city)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                                    .padding(12)
                                }

                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GENERAL ADMISSION")
                                            .font(.system(size: 9, weight: .semibold))
                                            .tracking(1.3)
                                            .foregroundStyle(Theme.textTertiary)
                                        Text("1 ticket")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    Text(room.priceLabel)
                                        .font(.system(size: 26, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textPrimary)
                                }

                                Divider().overlay(Theme.hairline)

                                HStack(spacing: 7) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                    Text("Entry is checked at the door — in person or remotely.")
                                        .font(.system(size: 12))
                                }
                                .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(14)
                        }
                        .panel(radius: Theme.cardRadius)
                        .padding(.horizontal, Theme.margin)

                        if isPurchased {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.openDoor)
                                Text("You're in — welcome to \(room.name).")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 0)

                        payButton(room)
                    }
                    .padding(.bottom, 18)
                    .animation(Theme.gentle, value: isPurchased)
                }
            }
            .navigationTitle("Get your ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .disabled(isProcessing)
                }
            }
        }
        .presentationDetents([.height(480)])
        .interactiveDismissDisabled(isProcessing)
    }

    @ViewBuilder
    private func payButton(_ room: Room) -> some View {
        if isPurchased {
            Button {
                dismiss()
            } label: {
                PrimaryButtonLabel(title: "Enter the room", symbol: "arrow.right.circle.fill")
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Theme.margin)
        } else {
            Button {
                processPayment(room)
            } label: {
                HStack(spacing: 7) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Buy ticket for \(room.priceLabel)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.accent, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.pressable)
            .disabled(isProcessing)
            .padding(.horizontal, Theme.margin)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
            } else {
                Text("Simulated checkout for the prototype — no real payment is made.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func processPayment(_ room: Room) {
        isProcessing = true
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task { @MainActor in
            do {
                try await store.purchaseTicket(room.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(Theme.gentle) {
                    isProcessing = false
                    isPurchased = true
                }
            } catch {
                withAnimation(Theme.gentle) { isProcessing = false }
                errorMessage = "The payment couldn't be completed. Please try again."
            }
        }
    }
}

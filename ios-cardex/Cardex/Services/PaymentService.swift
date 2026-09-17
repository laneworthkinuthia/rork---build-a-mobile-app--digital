import Foundation

/// Abstraction for processing event-ticket payments. A real provider (e.g. a
/// payment backend with server-side receipt validation) implements this in
/// production; the UI never talks to a payment provider directly.
protocol PaymentProcessing {
    /// Charges the ticket price for `event`. Throws when the payment cannot
    /// be completed — the caller must NOT grant entry on a thrown error.
    func processTicketPurchase(amount: Double, currency: String, event: String) async throws
}

/// Development-only simulated processor used while no payment provider is
/// configured. It performs NO transaction, touches no money, and collects no
/// payment information. Production must replace this with a real
/// `PaymentProcessing` implementation (see PRODUCTION_READINESS.md, P0).
final class SimulatedPaymentProcessor: PaymentProcessing {
    /// Delay so the checkout UI behaves like a real (slow) processor in demos.
    var simulatedDelay: Duration = .seconds(1.1)

    func processTicketPurchase(amount: Double, currency: String, event: String) async throws {
        try await Task.sleep(for: simulatedDelay)
        // Intentionally no side effects — this is a simulation, not a charge.
    }
}

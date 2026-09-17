import Foundation
import Observation
import os

/// Abstraction over message storage. The store and views never touch messages
/// directly, so a backend implementation can replace the local one without
/// UI changes.
@MainActor
protocol MessageRepository: AnyObject {
    var messages: [Message] { get }
    func add(_ message: Message)
    /// Removes every message to/from a person — used when a connection is removed.
    func removeMessages(with participantID: UUID)
}

/// Local development implementation. Persists messages to a JSON file under
/// Documents, seeds sample conversations on first launch, and can generate
/// simulated replies so threads feel alive in the prototype.
///
/// THIS IS NOT REAL MESSAGING: replies are canned, there is no transport and
/// no other user. A backend `MessageRepository` must replace this before
/// release (see PRODUCTION_READINESS.md, P0).
@MainActor
@Observable
final class LocalMessageRepository: MessageRepository {
    private(set) var messages: [Message] = []

    private let ownerID: UUID
    private let fileURL: URL?

    /// Canned replies used only by the development simulation.
    static let simulatedReplies = [
        "Good thinking — let's pick this up at the next mixer.",
        "Makes sense. I'll send something over later today.",
        "Ha, that's exactly what I was about to say.",
        "Sounds good — Thursday works for me.",
        "Just saw this. Free for a quick call tomorrow?"
    ]

    /// - Parameters:
    ///   - ownerID: The local user's card id; seeds are addressed to them and
    ///     the persistence file is namespaced by it.
    ///   - fileURL: Override for tests; defaults to a per-owner file in Documents.
    init(ownerID: UUID, fileURL: URL? = nil) {
        self.ownerID = ownerID
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("messages-\(ownerID.uuidString).json")
        }
        loadOrSeed()
    }

    func add(_ message: Message) {
        messages.append(message)
        save()
    }

    func removeMessages(with participantID: UUID) {
        messages.removeAll { $0.senderID == participantID || $0.recipientID == participantID }
        save()
    }

    /// A canned reply for the development simulation. Production repositories
    /// would not generate replies — incoming messages arrive from the backend.
    func makeSimulatedReply(from partnerID: UUID) -> Message {
        Message(
            senderID: partnerID,
            recipientID: ownerID,
            text: Self.simulatedReplies.randomElement() ?? "Sounds good!"
        )
    }

    private func loadOrSeed() {
        if let fileURL,
           let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([Message].self, from: data),
           !stored.isEmpty {
            messages = stored
        } else {
            messages = SampleData.makeSeedMessages(ownerID: ownerID)
            save()
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.persistence.error("Failed to save messages: \(error.localizedDescription, privacy: .public)")
        }
    }
}

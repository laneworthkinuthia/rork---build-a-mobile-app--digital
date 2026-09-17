import Foundation

/// A single message exchanged with a connection in the in-app inbox.
nonisolated struct Message: Identifiable, Hashable {
    let id: UUID
    let senderID: UUID
    let recipientID: UUID
    var text: String
    let sentAt: Date

    init(id: UUID = UUID(), senderID: UUID, recipientID: UUID, text: String, sentAt: Date = Date()) {
        self.id = id
        self.senderID = senderID
        self.recipientID = recipientID
        self.text = text
        self.sentAt = sentAt
    }
}

/// A thread of messages between the owner and one connection.
nonisolated struct Conversation: Identifiable, Hashable {
    let partner: BusinessCard
    let messages: [Message]
    /// Incoming messages the owner has not seen yet.
    let unreadCount: Int

    var id: UUID { partner.id }
    var lastMessage: Message? { messages.last }
}

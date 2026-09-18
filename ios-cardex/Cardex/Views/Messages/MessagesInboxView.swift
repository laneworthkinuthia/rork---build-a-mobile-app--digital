import SwiftUI

/// The in-app messaging inbox: one thread per connection with messages.
struct MessagesInboxView: View {
    @Environment(CardexStore.self) private var store
    @Binding var path: [ProfileRoute]

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.conversations.isEmpty {
                        EmptyStateView(
                            symbol: "bubble.left.and.bubble.right",
                            title: "No conversations yet",
                            message: "Message someone from their card after you've exchanged or connected."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.conversations.enumerated()), id: \.element.id) { index, conversation in
                                row(for: conversation)
                                if index < store.conversations.count - 1 {
                                    Divider().overlay(Theme.hairline).padding(.leading, 66)
                                }
                            }
                        }
                        .panel()
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }

    private func row(for conversation: Conversation) -> some View {
        Button { path.append(.conversation(conversation.id)) } label: {
            HStack(spacing: 12) {
                Avatar(card: conversation.partner, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.partner.name)
                        .font(.system(size: 16, weight: conversation.unreadCount > 0 ? .semibold : .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(preview(for: conversation))
                        .font(.system(size: 13))
                        .foregroundStyle(conversation.unreadCount > 0 ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(conversation.lastMessage?.sentAt.shortRelativeLabel ?? "")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: .capsule)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("inbox-row")
    }

    private func preview(for conversation: Conversation) -> String {
        guard let last = conversation.lastMessage else { return "" }
        return last.senderID == store.owner.id ? "You: \(last.text)" : last.text
    }
}

import SwiftUI

/// A single message thread with a connection: bubbles plus an input bar.
struct ConversationView: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let partnerID: UUID
    /// Set when presented in a sheet, where there is no system back button.
    var showsBackButton = false

    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private var partner: BusinessCard? { store.card(withID: partnerID) }
    private var thread: [Message] { store.messages(with: partnerID) }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if let partner {
                threadList
                inputBar(partner)
            } else {
                EmptyStateView(
                    symbol: "person.slash",
                    title: "Conversation unavailable",
                    message: "This person is no longer in your network."
                )
                Spacer(minLength: 0)
            }
        }
        .background(Theme.canvas)
        .navigationTitle(partner?.name ?? "Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .onAppear { store.markThreadRead(partnerID) }
    }

    private var threadList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(thread) { message in
                        MessageBubble(
                            text: message.text,
                            time: message.sentAt.shortRelativeLabel,
                            isFromOwner: message.senderID == store.owner.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .onChange(of: thread.count) { _, _ in
                guard let last = thread.last else { return }
                withAnimation(Theme.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func inputBar(_ partner: BusinessCard) -> some View {
        HStack(spacing: 10) {
            TextField("Message \(partner.firstName)…", text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface, in: .capsule)
                .focused($isInputFocused)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(canSend ? Theme.accent : Theme.surfaceHigh, in: .circle)
            }
            .buttonStyle(.pressable)
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 10)
    }

    private func send() {
        store.sendMessage(draft, to: partnerID)
        draft = ""
        isInputFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// One chat bubble — indigo on the right for the owner, surface on the left.
struct MessageBubble: View {
    let text: String
    let time: String
    let isFromOwner: Bool

    var body: some View {
        HStack {
            if isFromOwner { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(isFromOwner ? Color.white : Theme.textPrimary)
                Text(time)
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(isFromOwner ? Color.white.opacity(0.6) : Theme.textTertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                isFromOwner ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceHigh),
                in: .rect(cornerRadius: 16, style: .continuous)
            )

            if !isFromOwner { Spacer(minLength: 60) }
        }
    }
}

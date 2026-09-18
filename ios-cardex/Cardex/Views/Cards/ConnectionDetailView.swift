import SwiftUI

/// A collected person's card: flip between the front and their contact details,
/// with the meeting note and contact actions below.
struct ConnectionDetailView: View {
    @Environment(CardexStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    let connectionID: UUID
    @State private var isFlipped = true
    @State private var isEditingNote = false
    @State private var draftNote = ""
    @State private var isShowingAccessSheet = false
    @State private var isShowingStories = false
    @State private var isShowingChat = false
    @State private var isConfirmingBlock = false
    @State private var isShowingReport = false
    @State private var reportReason = ""

    private var connection: Connection? {
        store.connections.first { $0.id == connectionID }
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            if let connection {
                content(for: connection)
            } else {
                EmptyStateView(
                    symbol: "rectangle.on.rectangle.slash",
                    title: "Card removed",
                    message: "This card is no longer in your connections."
                )
            }
        }
        .navigationTitle(connection?.card.name ?? "Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if let connection {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.toggleFavorite(connection.id)
                        } label: {
                            Label(
                                connection.isFavorite ? "Remove favourite" : "Favourite",
                                systemImage: connection.isFavorite ? "star.slash" : "star"
                            )
                        }
                        Button {
                            draftNote = connection.note
                            isEditingNote = true
                        } label: {
                            Label("Edit note", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            store.removeConnection(connection.id)
                            dismiss()
                        } label: {
                            Label("Remove card", systemImage: "trash")
                        }
                        Divider()
                        Button(role: .destructive) {
                            isConfirmingBlock = true
                        } label: {
                            Label("Block", systemImage: "hand.raised")
                        }
                        Button {
                            reportReason = ""
                            isShowingReport = true
                        } label: {
                            Label("Report", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingNote) {
            NoteEditor(note: $draftNote) {
                store.updateNote(draftNote, for: connectionID)
            }
        }
        .sheet(isPresented: $isShowingAccessSheet) {
            if let connection {
                RequestAccessSheet(connection: connection)
            }
        }
        .sheet(isPresented: $isShowingChat) {
            if let card = connection?.card {
                NavigationStack {
                    ConversationView(partnerID: card.id, showsBackButton: true)
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingStories) {
            if let card = connection?.card {
                StoryViewer(cards: [card], startIndex: 0)
            }
        }
        .confirmationDialog(
            "Block \(connection?.card.name ?? "this person")?",
            isPresented: $isConfirmingBlock,
            titleVisibility: .visible,
        ) {
            Button("Block", role: .destructive) {
                if let connection {
                    store.blockUser(connection.card)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll be removed from your connections and you won't be able to exchange cards, message each other, or see each other in Cardex.")
        }
        .alert("Report \(connection?.card.firstName ?? "this person")?", isPresented: $isShowingReport) {
            TextField("What happened?", text: $reportReason)
            Button("Send Report", role: .destructive) {
                if let connection {
                    store.reportUser(connection.card, reason: reportReason)
                }
                reportReason = ""
            }
            Button("Cancel", role: .cancel) { reportReason = "" }
        } message: {
            Text("Your report goes to the Cardex team. The person you report won't be told.")
        }
    }

    @ViewBuilder
    private func content(for connection: Connection) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                FlippableCard(isFlipped: $isFlipped) {
                    BusinessCardFront(card: connection.card) { flipBadge(title: "Back") }
                } back: {
                    BusinessCardBack(
                        card: connection.card,
                        visibleDetails: connection.visibleDetails,
                        lockedDetails: connection.lockedDetails
                    )
                    .overlay(alignment: .topTrailing) {
                        flipBadge(title: "Front").padding(18)
                    }
                }
                .frame(height: 360)
                .padding(.horizontal, Theme.margin)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    isFlipped.toggle()
                }

                if connection.card.hasActiveStories {
                    storiesButton(for: connection.card)
                }

                if !connection.lockedDetails.isEmpty {
                    lockedBanner(for: connection)
                }

                detailList(for: connection)
                meetingNote(for: connection)
                actionRow(for: connection)

                if !connection.card.skills.isEmpty {
                    skillsSection(for: connection.card)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func flipBadge(title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 11, weight: .semibold))
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: .capsule)
        .allowsHitTesting(false)
    }

    private func storiesButton(for card: BusinessCard) -> some View {
        Button {
            isShowingStories = true
        } label: {
            HStack(spacing: 12) {
                StoryAvatar(card: card, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent updates")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(card.activeStories.count) photo\(card.activeStories.count == 1 ? "" : "s") from the last 24 hours")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .panel()
            .padding(.horizontal, Theme.margin)
        }
        .buttonStyle(.pressable)
    }

    private func lockedBanner(for connection: Connection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: connection.accessRequestPending ? "hourglass" : "lock.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.warning)
                .frame(width: 38, height: 38)
                .background(Theme.warning.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.accessRequestPending ? "Request sent" : "\(connection.lockedDetails.count) details are private")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(connection.accessRequestPending
                     ? "Waiting for \(connection.card.firstName) to approve."
                     : "Ask \(connection.card.firstName) to unlock them.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            if !connection.accessRequestPending {
                Button("Request") { isShowingAccessSheet = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 33)
                    .background(Theme.accent, in: .capsule)
                    .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .panel()
        .padding(.horizontal, Theme.margin)
    }

    private func detailList(for connection: Connection) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(connection.visibleDetails.enumerated()), id: \.element.id) { index, detail in
                Button {
                    if let url = detail.actionURL { openURL(url) }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: detail.kind.symbol)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(Theme.surfaceHigh, in: .rect(cornerRadius: 11))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(detail.kind.label)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                            Text(detail.value)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)

                if index < connection.visibleDetails.count - 1 {
                    Divider().overlay(Theme.hairline).padding(.leading, 65)
                }
            }
        }
        .panel()
        .padding(.horizontal, Theme.margin)
    }

    private func meetingNote(for connection: Connection) -> some View {
        Button {
            draftNote = connection.note
            isEditingNote = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Theme.surfaceHigh, in: .rect(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.metLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(connection.note.isEmpty ? "Add a note" : connection.note)
                        .font(.system(size: 13))
                        .foregroundStyle(connection.note.isEmpty ? Theme.textTertiary : Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .panel()
            .padding(.horizontal, Theme.margin)
        }
        .buttonStyle(.pressable)
    }

    private func actionRow(for connection: Connection) -> some View {
        HStack(spacing: 10) {
            let mobile = connection.visibleDetails.first { $0.kind == .mobile }

            ActionTile(title: "Call", symbol: "phone.fill", isEnabled: mobile != nil) {
                // Simply places a call to their primary phone number.
                if let url = mobile?.actionURL { openURL(url) }
            }
            ActionTile(title: "Message", symbol: "bubble.left.fill", isEnabled: true) {
                isShowingChat = true
            }
            ActionTile(
                title: connection.accessRequestPending ? "Pending" : "Request Access",
                symbol: connection.accessRequestPending ? "hourglass" : "lock.open.fill",
                isEnabled: !connection.accessRequestPending && !connection.lockedDetails.isEmpty
            ) {
                isShowingAccessSheet = true
            }
        }
        .padding(.horizontal, Theme.margin)
    }

    private func skillsSection(for card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Skills")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(card.skills, id: \.self) { skill in
                    TagPill(text: skill)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panel()
        .padding(.horizontal, Theme.margin)
    }
}

/// Square action button used in the contact action row.
struct ActionTile: View {
    let title: String
    let symbol: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isEnabled ? Theme.accent : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .panel()
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }
}

/// Sheet for editing the note attached to a collected card.
struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var note: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                VStack(spacing: 14) {
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(12)
                        .frame(height: 160)
                        .panel()
                    Spacer(minLength: 0)
                }
                .padding(Theme.margin)
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

import Foundation

/// A single contact detail shown on the back of a card.
nonisolated struct ContactDetail: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case mobile, email, website, linkedin, instagram, x, tiktok

        var label: String {
            switch self {
            case .mobile: "Mobile"
            case .email: "Email"
            case .website: "Website"
            case .linkedin: "LinkedIn"
            case .instagram: "Instagram"
            case .x: "X"
            case .tiktok: "TikTok"
            }
        }

        var symbol: String {
            switch self {
            case .mobile: "phone.fill"
            case .email: "envelope.fill"
            case .website: "globe"
            case .linkedin: "briefcase.fill"
            case .instagram: "camera.fill"
            case .x: "at"
            case .tiktok: "music.note"
            }
        }

        /// Contact kinds that are sensitive by default and hidden in Private mode.
        var isSensitiveByDefault: Bool {
            switch self {
            case .mobile, .email: true
            default: false
            }
        }
    }

    let id: UUID
    let kind: Kind
    var value: String
    /// Tiers that may see this detail without an explicit approval.
    var tier: AccessTier

    init(id: UUID = UUID(), kind: Kind, value: String, tier: AccessTier = .connected) {
        self.id = id
        self.kind = kind
        self.value = value
        self.tier = tier
    }

    var actionURL: URL? {
        switch kind {
        case .mobile:
            URL(string: "tel:\(value.filter { $0.isNumber || $0 == "+" })")
        case .email:
            URL(string: "mailto:\(value)")
        case .website:
            URL(string: value.hasPrefix("http") ? value : "https://\(value)")
        case .linkedin:
            URL(string: "https://linkedin.com\(value)")
        case .instagram:
            URL(string: "https://instagram.com/\(value.replacingOccurrences(of: "@", with: ""))")
        case .x:
            URL(string: "https://x.com/\(value.replacingOccurrences(of: "@", with: ""))")
        case .tiktok:
            URL(string: "https://tiktok.com/\(value)")
        }
    }
}

/// Who a piece of information is shared with.
nonisolated enum AccessTier: String, CaseIterable, Identifiable, Codable {
    case publicTier = "public"
    case connected
    case trusted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .publicTier: "Public"
        case .connected: "Connected"
        case .trusted: "Trusted"
        }
    }

    /// The lower of the two tiers — used to clamp grants to privacy ceilings.
    func clamped(by ceiling: AccessTier) -> AccessTier {
        rank <= ceiling.rank ? self : ceiling
    }

    var caption: String {
        switch self {
        case .publicTier: "Anyone who sees your card"
        case .connected: "People you have exchanged cards with"
        case .trusted: "Only people you personally approve"
        }
    }

    var rank: Int {
        switch self {
        case .publicTier: 0
        case .connected: 1
        case .trusted: 2
        }
    }
}

/// A recent photo update that expires 24 hours after posting.
nonisolated struct StoryUpdate: Identifiable, Hashable, Codable {
    let id: UUID
    let imageName: String
    let caption: String
    let postedAt: Date
    /// Camera or library photo, used instead of the bundled asset when set.
    var imageData: Data?

    init(id: UUID = UUID(), imageName: String, caption: String, postedAt: Date, imageData: Data? = nil) {
        self.id = id
        self.imageName = imageName
        self.caption = caption
        self.postedAt = postedAt
        self.imageData = imageData
    }

    var isActive: Bool { Date().timeIntervalSince(postedAt) < 24 * 3600 }

    var remainingLabel: String {
        let hours = max(0, 24 - Int(Date().timeIntervalSince(postedAt) / 3600))
        return hours <= 1 ? "Expires soon" : "\(hours)h left"
    }
}

/// A person's digital business card — the identity layer of the app.
nonisolated struct BusinessCard: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var title: String
    var company: String
    var industry: String
    var tagline: String
    var location: String
    var photoName: String
    var palette: CardPalette
    var monogram: String
    var details: [ContactDetail]
    var credentials: [String]
    var skills: [String]
    var visibility: VisibilityMode
    var stories: [StoryUpdate]
    /// Camera or library photo chosen by the user; wins over the bundled asset.
    var photoData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        title: String,
        company: String,
        industry: String,
        tagline: String,
        location: String,
        photoName: String,
        palette: CardPalette,
        monogram: String,
        details: [ContactDetail],
        credentials: [String] = [],
        skills: [String] = [],
        visibility: VisibilityMode = .live,
        stories: [StoryUpdate] = [],
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.company = company
        self.industry = industry
        self.tagline = tagline
        self.location = location
        self.photoName = photoName
        self.palette = palette
        self.monogram = monogram
        self.details = details
        self.credentials = credentials
        self.skills = skills
        self.visibility = visibility
        self.stories = stories
        self.photoData = photoData
    }

    /// True when the card shows a monogram avatar instead of a photo.
    var isAvatarOnly: Bool { (photoData?.isEmpty ?? true) && photoName.isEmpty }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var activeStories: [StoryUpdate] { stories.filter(\.isActive) }
    var hasActiveStories: Bool { !activeStories.isEmpty }
}

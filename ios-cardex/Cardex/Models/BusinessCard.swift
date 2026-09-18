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

    /// Storage for user-picked story photos. Injectable for tests.
    nonisolated(unsafe) static var mediaStore: any MediaStoring = FileMediaStore()

    // MARK: - Codable

    // Story photo blobs are stored on disk via MediaStoring, never inside the
    // JSON payload. The legacy inline-blob format is still decoded.

    private enum CodingKeys: String, CodingKey {
        case id, imageName, caption, postedAt
        case imageReference, imageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageName = try container.decode(String.self, forKey: .imageName)
        caption = try container.decode(String.self, forKey: .caption)
        postedAt = try container.decode(Date.self, forKey: .postedAt)

        if let reference = try container.decodeIfPresent(String.self, forKey: .imageReference),
           let data = Self.mediaStore.loadData(forReference: reference) {
            imageData = data
        } else {
            imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageName, forKey: .imageName)
        try container.encode(caption, forKey: .caption)
        try container.encode(postedAt, forKey: .postedAt)
        if let imageData {
            if let reference = Self.mediaStore.store(imageData, forKey: "story-\(id.uuidString)") {
                try container.encode(reference, forKey: .imageReference)
            } else {
                // Store-less transport (backend sync): inline the bytes so
                // other devices receive the image.
                try container.encode(imageData, forKey: .imageData)
            }
        }
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

    /// Storage for user-picked photos. Injectable so tests can isolate disk IO.
    nonisolated(unsafe) static var mediaStore: any MediaStoring = FileMediaStore()

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

    // MARK: - Codable

    // Photo blobs are stored on disk via MediaStoring, never inside the JSON
    // payload (which lives in UserDefaults). The legacy inline-blob format is
    // still decoded so previously persisted cards keep working.

    private enum CodingKeys: String, CodingKey {
        case id, name, title, company, industry, tagline, location, photoName, palette
        case monogram, details, credentials, skills, visibility, stories
        case photoReference, photoData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decode(String.self, forKey: .title)
        company = try container.decode(String.self, forKey: .company)
        industry = try container.decode(String.self, forKey: .industry)
        tagline = try container.decode(String.self, forKey: .tagline)
        location = try container.decode(String.self, forKey: .location)
        photoName = try container.decode(String.self, forKey: .photoName)
        palette = try container.decode(CardPalette.self, forKey: .palette)
        monogram = try container.decode(String.self, forKey: .monogram)
        details = try container.decode([ContactDetail].self, forKey: .details)
        credentials = try container.decode([String].self, forKey: .credentials)
        skills = try container.decode([String].self, forKey: .skills)
        visibility = try container.decode(VisibilityMode.self, forKey: .visibility)
        stories = try container.decode([StoryUpdate].self, forKey: .stories)

        if let reference = try container.decodeIfPresent(String.self, forKey: .photoReference),
           let data = Self.mediaStore.loadData(forReference: reference) {
            photoData = data
        } else {
            photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(company, forKey: .company)
        try container.encode(industry, forKey: .industry)
        try container.encode(tagline, forKey: .tagline)
        try container.encode(location, forKey: .location)
        try container.encode(photoName, forKey: .photoName)
        try container.encode(palette, forKey: .palette)
        try container.encode(monogram, forKey: .monogram)
        try container.encode(details, forKey: .details)
        try container.encode(credentials, forKey: .credentials)
        try container.encode(skills, forKey: .skills)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(stories, forKey: .stories)
        if let photoData {
            if let reference = Self.mediaStore.store(photoData, forKey: "card-\(id.uuidString)-photo") {
                try container.encode(reference, forKey: .photoReference)
            } else {
                // Store-less transport (backend sync): inline the bytes so
                // other devices receive the photo.
                try container.encode(photoData, forKey: .photoData)
            }
        }
    }

    /// True when the card shows a monogram avatar instead of a photo.
    var isAvatarOnly: Bool { (photoData?.isEmpty ?? true) && photoName.isEmpty }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var activeStories: [StoryUpdate] { stories.filter(\.isActive) }
    var hasActiveStories: Bool { !activeStories.isEmpty }
}

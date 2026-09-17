import os

/// Central loggers. Only operational diagnostics go through these — never
/// message content, contact details, or other personal data.
/// `nonisolated`: used from off-main code paths (media storage, Codable).
nonisolated enum Log {
    static let persistence = Logger(subsystem: "Cardex", category: "persistence")
    static let media = Logger(subsystem: "Cardex", category: "media")
}

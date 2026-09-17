import Foundation
import os

/// Boundary for user-generated media (profile photos, story images).
/// Media is stored on disk — never in `UserDefaults`. A production backend
/// implementation can replace this without touching the models or UI.
/// `nonisolated`: called from Codable paths, which run off the main actor.
nonisolated protocol MediaStoring: AnyObject {
    /// Stores `data` under `key` (overwriting any previous value) and returns
    /// a reference string that can be persisted in JSON. Returns nil on failure.
    func store(_ data: Data, forKey key: String) -> String?

    /// Loads the data previously stored under `reference`, if it still exists.
    func loadData(forReference reference: String) -> Data?
}

/// File-based local implementation used while the app has no backend.
/// Blobs live under Application Support/CardexMedia so they are excluded from
/// iCloud backups by default and never bloat UserDefaults.
nonisolated final class FileMediaStore: MediaStoring {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("CardexMedia", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func store(_ data: Data, forKey key: String) -> String? {
        let reference = "\(key).dat"
        let url = directory.appendingPathComponent(reference)
        do {
            try data.write(to: url, options: .atomic)
            return reference
        } catch {
            Log.media.error("Failed to store media '\(key, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadData(forReference reference: String) -> Data? {
        guard !reference.contains("/") else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(reference))
    }
}

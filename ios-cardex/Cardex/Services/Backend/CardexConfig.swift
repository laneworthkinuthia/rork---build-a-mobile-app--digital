import Foundation

/// Typed access to the public backend/auth configuration. Values arrive via
/// the build-time-injected `Config` (see Config.swift); two values that are
/// stable public identifiers fall back to their known literals so local builds
/// still reach the beta backend.
enum CardexConfig {
    /// Cloudflare Worker + Durable Object backend for the beta.
    static var functionsURL: URL {
        let raw = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        if !raw.isEmpty, let url = URL(string: raw) { return url }
        return URL(string: "https://build-a-mobile-app-digital-business-card-backend.rork.app")!
    }

    static var functionsURLString: String { functionsURL.absoluteString }

    static var authURL: String { Config.EXPO_PUBLIC_RORK_AUTH_URL }

    static var appKey: String { Config.EXPO_PUBLIC_RORK_APP_KEY }

    static var projectID: String {
        let raw = Config.EXPO_PUBLIC_PROJECT_ID
        return raw.isEmpty ? "p8bgff7cw7kasw6687yah" : raw
    }

    /// URL scheme the OAuth browser redirects back into.
    static var callbackScheme: String { "rork-\(projectID)" }

    /// WebSocket endpoint derived from the functions URL.
    static var webSocketURL: URL? {
        var components = URLComponents(url: functionsURL, resolvingAgainstBaseURL: false)
        components?.scheme = "wss"
        components?.path = "/ws"
        return components?.url
    }

    /// True when every value needed to reach the beta backend is present.
    static var isBackendConfigured: Bool {
        !functionsURLString.isEmpty && !authURL.isEmpty && !appKey.isEmpty
    }
}

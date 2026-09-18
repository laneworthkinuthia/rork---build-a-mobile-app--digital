import SwiftUI
import AuthenticationServices
import CryptoKit

/// Rork Auth session holder: Apple/Google sign-in via ASWebAuthenticationSession
/// (with the Rork simulator popup flow when available), tokens in the Keychain,
/// silent refresh between launches.
@Observable
@MainActor
final class AuthManager {
    struct User: Codable, Equatable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    private(set) var user: User?
    var isRestoringSession = true
    var isSigningIn = false
    /// surfaced when a sign-in attempt fails
    var authError: String?

    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    /// The Rork-issued access token for backend calls.
    var accessToken: String? { KeychainHelper.get("access_token") }

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session lifecycle

    func restoreSession() async {
        defer { isRestoringSession = false }

        if let token = KeychainHelper.get("access_token"), let user = Self.userFromToken(token) {
            self.user = user
            return
        }

        // Token missing or expired — try a silent refresh.
        if refreshToken() != nil {
            try? await refresh()
        }
    }

    func signOut() {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        user = nil
    }

    /// Returns a token that is still valid, refreshing when it is about to
    /// expire. Used before every backend call.
    func ensureFreshToken() async throws -> String {
        if let token = accessToken, let payload = Self.payload(from: token),
           let exp = payload.exp, Date(timeIntervalSince1970: exp) > Date().addingTimeInterval(60) {
            return token
        }
        try await refresh()
        guard let token = accessToken else {
            throw BackendError(kind: .unauthenticated, userMessage: "Your session expired. Please sign in again.")
        }
        return token
    }

    // MARK: - Sign in

    func signIn(provider: String) async {
        guard CardexConfig.isBackendConfigured else {
            authError = "The beta backend is not configured in this build."
            return
        }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }
        do {
            let verifier = Self.generateCodeVerifier()
            let challenge = Self.generateCodeChallenge(from: verifier)
            codeVerifier = verifier

            var initiateBody: [String: String] = [
                "app_key": CardexConfig.appKey,
                "provider": provider,
                "code_challenge": challenge,
                "target": "swift",
                "env": authEnv,
            ]
            if authEnv == "simulator", let hint = developerHint {
                initiateBody["developer_hint"] = hint
            }

            let initiate = try await Self.post(
                url: URL(string: "\(CardexConfig.authURL)/oauth/initiate"),
                body: initiateBody,
                decode: InitiateResponse.self,
            )

            let code: String
            if initiate.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiate.state)
                } catch AuthError.cancelledByUser {
                    // The developer chose "Use simulator instead" — the same
                    // auth_url now redirects in-app, so reuse it.
                    code = try await runWebAuthSession(authURL: initiate.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiate.auth_url)
            }

            try await exchangeCode(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch AuthError.cancelledByUser {
            return
        } catch {
            authError = Self.userMessage(for: error)
        }
    }

    // MARK: - Internals

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    /// Injected by Rork into simulator UserDefaults only; selects the
    /// developer-browser popup flow. Computed so late simctl writes still land.
    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    private func refreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") {
            return injected
        }
        #endif
        return KeychainHelper.get("refresh_token")
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(CardexConfig.authURL)/oauth/poll-code") else {
            throw AuthError.invalidURL
        }

        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(1.5))

            guard let response = try? await Self.postRaw(
                url: url,
                body: ["app_key": CardexConfig.appKey, "state": state],
            ) else { continue }

            guard let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: response) else { continue }
            if poll.status == "cancelled" { throw AuthError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw AuthError.popupTimeout
    }

    private func runWebAuthSession(authURL: String) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: authURL) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: CardexConfig.callbackScheme,
            ) { callbackURL, error in
                self.webAuthSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }

            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCode(_ code: String) async throws {
        guard let verifier = codeVerifier else { throw AuthError.noCode }
        codeVerifier = nil

        let token = try await Self.post(
            url: URL(string: "\(CardexConfig.authURL)/oauth/token"),
            body: ["app_key": CardexConfig.appKey, "code": code, "code_verifier": verifier],
            decode: TokenResponse.self,
        )
        KeychainHelper.set("access_token", value: token.access_token)
        KeychainHelper.set("refresh_token", value: token.refresh_token)
        user = token.user
    }

    private func refresh() async throws {
        guard let stored = refreshToken() else {
            signOut()
            return
        }

        do {
            let response = try await Self.post(
                url: URL(string: "\(CardexConfig.authURL)/oauth/refresh"),
                body: ["app_key": CardexConfig.appKey, "refresh_token": stored],
                decode: RefreshResponse.self,
            )
            KeychainHelper.set("access_token", value: response.access_token)
            user = Self.userFromToken(response.access_token)
        } catch {
            signOut()
            throw BackendError(kind: .unauthenticated, userMessage: "Your session expired. Please sign in again.")
        }
    }

    // MARK: - Token parsing / networking helpers

    private struct JWTPayload: Codable {
        let sub: String
        let email: String?
        let name: String?
        let picture: String?
        let exp: TimeInterval?
    }

    static func userFromToken(_ token: String) -> User? {
        guard let payload = payload(from: token) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() { return nil }
        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }

    private static func payload(from token: String) -> JWTPayload? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(JWTPayload.self, from: data)
    }

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func post<Decoded: Decodable>(
        url: URL?,
        body: [String: String],
        decode: Decoded.Type,
    ) async throws -> Decoded {
        let data = try await postRaw(url: url, body: body)
        return try JSONDecoder().decode(Decoded.self, from: data)
    }

    private static func postRaw(url: URL?, body: [String: String]) async throws -> Data {
        guard let url else { throw AuthError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                if let apiError = try? JSONDecoder().decode(AuthAPIError.self, from: data) {
                    throw AuthError.server(apiError.error)
                }
                throw AuthError.server("HTTP \(status)")
            }
            return data
        } catch let error as AuthError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .timedOut {
            throw AuthError.offline
        }
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
        case AuthError.offline:
            return "You appear to be offline. Check your connection and try again."
        case AuthError.server(let detail):
            return "Sign in failed: \(detail)"
        case AuthError.popupTimeout:
            return "Sign-in timed out — please try again."
        default:
            return "Sign in failed. Please try again."
        }
    }
}

// MARK: - Response types

private struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

private struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthManager.User
}

private struct RefreshResponse: Codable {
    let access_token: String
    let expires_in: Int
}

private struct AuthAPIError: Codable {
    let error: String
}

enum AuthError: LocalizedError {
    case noCode
    case invalidURL
    case server(String)
    case popupTimeout
    case cancelledByUser
    case offline

    var errorDescription: String? {
        switch self {
        case .noCode: "No authorization code received"
        case .invalidURL: "Invalid authentication URL"
        case .server(let detail): detail
        case .popupTimeout: "Sign-in timed out — please try again."
        case .cancelledByUser: "Sign-in cancelled"
        case .offline: "You appear to be offline."
        }
    }
}

// MARK: - Presentation anchor

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

import Foundation
import os

/// Typed errors with user-facing messages. Never surfaces raw internals.
struct BackendError: LocalizedError {
    enum Kind {
        case offline
        case unauthenticated
        case forbidden
        case notFound
        case conflict
        case paymentRequired
        case server
        case notConfigured
    }

    let kind: Kind
    let userMessage: String

    var errorDescription: String? { userMessage }
}

/// Thin HTTP client for the Cardex beta backend. Every authenticated request
/// carries the Rork Auth bearer token; the platform verifies it and stamps the
/// user identity before our Worker sees the request.
@MainActor
final class BackendClient {
    static let shared = BackendClient()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    private struct APIErrorBody: Decodable {
        let error: String?
        let message: String?
    }

    // MARK: - Core request

    func request<Body: Encodable, Decoded: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Body? = nil,
        token: String,
    ) async throws -> Decoded {
        let data = try await raw(path, method: method, body: body, token: token)
        do {
            return try decoder.decode(Decoded.self, from: data)
        } catch {
            Log.persistence.error("Failed to decode backend response for \(path, privacy: .public)")
            throw BackendError(kind: .server, userMessage: "The Cardex backend returned something unexpected. Try again.")
        }
    }

    func request<Body: Encodable>(
        _ path: String,
        method: String = "POST",
        body: Body? = nil,
        token: String,
    ) async throws {
        _ = try await raw(path, method: method, body: body, token: token)
    }

    private struct EmptyBody: Encodable {}

    func request(_ path: String, method: String = "POST", token: String) async throws {
        let empty: EmptyBody? = nil
        _ = try await raw(path, method: method, body: empty, token: token)
    }

    private func raw<Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        token: String,
    ) async throws -> Data {
        let bodyData = try body.map { try encoder.encode($0) }
        return try await raw(path, method: method, bodyData: bodyData, token: token)
    }

    private func raw(
        _ path: String,
        method: String,
        bodyData: Data?,
        token: String,
    ) async throws -> Data {
        guard CardexConfig.isBackendConfigured else {
            throw BackendError(kind: .notConfigured, userMessage: "The beta backend is not configured in this build.")
        }

        let url = CardexConfig.functionsURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BackendError(kind: .server, userMessage: "The Cardex backend is unreachable. Try again.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw Self.error(from: data, status: http.statusCode)
            }
            return data
        } catch let error as BackendError {
            throw error
        } catch let error as URLError
        where error.code == .notConnectedToInternet || error.code == .timedOut || error.code == .cannotFindHost || error.code == .cannotConnectToHost {
            throw BackendError(kind: .offline, userMessage: "You appear to be offline. Check your connection and try again.")
        }
    }

    private static func error(from data: Data, status: Int) -> BackendError {
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        let message = body?.message ?? "Something went wrong. Try again."
        let kind: BackendError.Kind
        switch status {
        case 401: kind = .unauthenticated
        case 402: kind = .paymentRequired
        case 403: kind = .forbidden
        case 404: kind = .notFound
        case 409: kind = .conflict
        default: kind = .server
        }
        return BackendError(kind: kind, userMessage: message)
    }

    // MARK: - Endpoints

    struct EmptyResponse: Decodable { let ok: Bool }

    func snapshot(token: String, opened: Bool) async throws -> BackendSnapshot {
        let data = try await raw("state\(opened ? "?opened=1" : "")", method: "GET", bodyData: nil, token: token)
        do {
            return try decoder.decode(BackendSnapshot.self, from: data)
        } catch {
            Log.persistence.error("Failed to decode backend snapshot")
            throw BackendError(kind: .server, userMessage: "The Cardex backend returned something unexpected. Try again.")
        }
    }

    /// PUT /me — the card is transport-encoded with inline photo blobs.
    func saveCard(_ card: BusinessCard, token: String) async throws {
        let cardJSON = try TransportCoding.cardData(card, encoder: encoder)
        guard let cardObject = try JSONSerialization.jsonObject(with: cardJSON) as? [String: Any] else {
            throw BackendError(kind: .server, userMessage: "Your card could not be prepared for saving.")
        }
        let bodyData = try JSONSerialization.data(withJSONObject: ["card": cardObject])
        _ = try await raw("me", method: "PUT", bodyData: bodyData, token: token)
    }

    func exchangePreview(code: String, token: String) async throws -> ExchangePreview {
        try await request("exchange/preview", method: "POST", body: CodeBody(code: code), token: token)
    }

    func exchange(code: String, place: String, token: String) async throws {
        try await request("exchange", method: "POST", body: ExchangeBody(code: code, place: place), token: token)
    }

    func sendAccessRequest(to: String, tier: AccessTier, context: String, token: String) async throws {
        try await request("requests", method: "POST", body: RequestBody(to: to, tier: tier.rawValue, context: context), token: token)
    }

    func resolveRequest(id: String, approve: Bool, tier: AccessTier?, token: String) async throws {
        try await request("requests/\(id)/resolve", method: "POST", body: ResolveBody(approve: approve, tier: tier?.rawValue), token: token)
    }

    func grantTier(partner: String, tier: AccessTier, token: String) async throws {
        try await request("connections/\(partner)/grant", method: "POST", body: GrantBody(tier: tier.rawValue), token: token)
    }

    func setFavorite(partner: String, on: Bool, token: String) async throws {
        try await request("connections/\(partner)/favorite", method: "POST", body: FavoriteBody(on: on), token: token)
    }

    func setNote(partner: String, note: String, token: String) async throws {
        try await request("connections/\(partner)/note", method: "POST", body: NoteBody(note: note), token: token)
    }

    func removeConnection(partner: String, token: String) async throws {
        try await request("connections/\(partner)/remove", method: "POST", token: token)
    }

    func sendMessage(to: String, text: String, token: String) async throws -> Message {
        let response: SentMessageResponse = try await request(
            "messages", method: "POST",
            body: MessageBody(to: to, text: text),
            token: token,
        )
        return response.message
    }

    func markRead(partner: String, token: String) async throws {
        try await request("read", method: "POST", body: PartnerBody(partner: partner), token: token)
    }

    func createRoom(_ input: CreateRoomInput, token: String) async throws -> String {
        let response: CreateRoomResponse = try await request("rooms", method: "POST", body: input, token: token)
        return response.roomID
    }

    func joinRoom(id: String, remote: Bool, token: String) async throws {
        try await request("rooms/\(id)/join", method: "POST", body: JoinBody(remote: remote), token: token)
    }

    func leaveRoom(id: String, token: String) async throws {
        try await request("rooms/\(id)/leave", method: "POST", token: token)
    }

    func buyTicket(id: String, token: String) async throws {
        try await request("rooms/\(id)/ticket", method: "POST", token: token)
    }

    func doorDecision(room: String, user: String, approve: Bool, token: String) async throws {
        let path = "rooms/\(room)/\(approve ? "approve" : "deny")"
        try await request(path, method: "POST", body: DoorBody(user: user), token: token)
    }

    func setBroadcast(room: String, on: Bool, token: String) async throws {
        try await request("rooms/\(room)/broadcast", method: "POST", body: BroadcastBody(on: on), token: token)
    }

    func createPost(body: String, audience: FeedPost.Audience, imageName: String?, token: String) async throws {
        try await request("posts", method: "POST", body: PostBody(body: body, audience: audience.rawValue, imageName: imageName), token: token)
    }

    func toggleApplause(post: String, token: String) async throws {
        try await request("posts/\(post)/applause", method: "POST", token: token)
    }

    func block(user: String, token: String) async throws {
        try await request("block", method: "POST", body: PartnerBody(partner: user), token: token)
    }

    func unblock(user: String, token: String) async throws {
        try await request("unblock", method: "POST", body: PartnerBody(partner: user), token: token)
    }

    func report(user: String, reason: String, token: String) async throws {
        try await request("report", method: "POST", body: ReportBody(user: user, reason: reason), token: token)
    }

    func deleteAccount(token: String) async throws {
        try await request("account/delete", method: "POST", token: token)
    }

    func track(_ event: String, token: String) async throws {
        try await request("analytics", method: "POST", body: EventBody(event: event), token: token)
    }
}

// MARK: - Bodies

struct CreateRoomInput: Encodable {
    let name: String
    let venue: String
    let city: String
    let blurb: String
    let imageName: String
    let access: String
    let ticketPrice: Double?
}

private struct CodeBody: Encodable { let code: String }
private struct ExchangeBody: Encodable { let code: String; let place: String }
private struct RequestBody: Encodable { let to: String; let tier: String; let context: String }
private struct ResolveBody: Encodable { let approve: Bool; let tier: String? }
private struct GrantBody: Encodable { let tier: String }
private struct FavoriteBody: Encodable { let on: Bool }
private struct NoteBody: Encodable { let note: String }
private struct MessageBody: Encodable { let to: String; let text: String }
private struct PartnerBody: Encodable { let partner: String }
private struct JoinBody: Encodable { let remote: Bool }
private struct DoorBody: Encodable { let user: String }
private struct BroadcastBody: Encodable { let on: Bool }
private struct PostBody: Encodable { let body: String; let audience: String; let imageName: String? }
private struct ReportBody: Encodable { let user: String; let reason: String }
private struct EventBody: Encodable { let event: String }

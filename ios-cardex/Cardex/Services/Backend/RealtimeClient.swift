import Foundation
import os

/// WebSocket connection to the beta backend for live events (new messages,
/// requests, connections, room updates). Reconnects with backoff; the store
/// also polls as a fallback so reliability never depends on the socket.
@MainActor
final class RealtimeClient: NSObject, URLSessionWebSocketDelegate {
    enum State: String {
        case idle
        case connecting
        case connected
        case disconnected
    }

    private(set) var state: State = .idle
    var onEvent: ((RealtimeEvent) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var token: String?
    private var isStopped = true

    private lazy var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func connect(token: String) {
        self.token = token
        isStopped = false
        openSocket()
    }

    func disconnect() {
        isStopped = true
        token = nil
        pingTask?.cancel()
        reconnectTask?.cancel()
        pingTask = nil
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .idle
    }

    private func openSocket() {
        guard !isStopped, let token, let url = CardexConfig.webSocketURL else { return }
        state = .connecting

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let socket = session.webSocketTask(with: request)
        task = socket
        socket.resume()
        receive()
        startPinging()
    }

    private func receive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.deliver(text)
                    case .data(let data):
                        self.deliver(data)
                    @unknown default:
                        break
                    }
                    self.receive()
                case .failure:
                    self.handleDisconnect()
                }
            }
        }
    }

    private func deliver(_ payload: String) {
        state = .connected
        reconnectAttempt = 0
        guard let data = payload.data(using: .utf8), let event = RealtimeEvent.parse(data) else { return }
        onEvent?(event)
    }

    private func deliver(_ payload: Data) {
        deliver(String(decoding: payload, as: UTF8.self))
    }

    private func startPinging() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard let self, !self.isStopped else { return }
                await self.ping()
            }
        }
    }

    private func ping() async {
        guard let task else { return }
        let pingError: Error? = await withCheckedContinuation { continuation in
            task.sendPing { error in
                continuation.resume(returning: error)
            }
        }
        if pingError != nil {
            handleDisconnect()
        }
    }

    private func handleDisconnect() {
        guard !isStopped else { return }
        state = .disconnected
        pingTask?.cancel()
        pingTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        reconnectAttempt += 1
        let delay = min(Double(reconnectAttempt) * 2, 30)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !self.isStopped else { return }
            self.openSocket()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {
        Task { @MainActor [weak self] in
            guard let self, self.task === webSocketTask else { return }
            self.state = .connected
            self.reconnectAttempt = 0
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor [weak self] in
            guard let self, self.task === webSocketTask else { return }
            self.handleDisconnect()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let socket = task as? URLSessionWebSocketTask else { return }
        Task { @MainActor [weak self] in
            guard let self, self.task === socket else { return }
            self.handleDisconnect()
        }
    }
}

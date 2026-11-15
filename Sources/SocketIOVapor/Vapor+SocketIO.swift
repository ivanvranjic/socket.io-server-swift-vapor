@_exported import SocketIOCore
import Foundation
import Vapor

extension Application {
    /// Entry point for Socket.IO: `app.socketIO.configure()` once at startup, then use `app.socketIO.server` anywhere.
    public var socketIO: SocketIOProvider { SocketIOProvider(application: self) }
}

extension Request {
    /// The server created by `app.socketIO.configure()`. Use it to emit from route handlers.
    public var socketIO: SocketIOServer { application.socketIO.server }
}

extension SocketIOSocket {
    /// The Vapor application this socket's server is mounted on.
    public var application: Application {
        server[storage: SocketIOProvider.applicationKey] as! Application
    }
}

public struct SocketIOProvider {
    let application: Application
    static let applicationKey = "vapor.application"

    private struct Key: StorageKey { typealias Value = SocketIOServer }
    private struct Lifecycle: LifecycleHandler {
        let server: SocketIOServer
        func shutdown(_ application: Application) { server.shutdown() }
    }

    /// Creates the server and mounts it on `path` (default `/socket.io`). Call once, during `configure(_:)`.
    @discardableResult
    public func configure(path: String = "socket.io", _ configuration: SocketIOConfiguration = SocketIOConfiguration()) -> SocketIOServer {
        precondition(application.storage[Key.self] == nil, "Socket.IO is already configured")
        let server = SocketIOServer(configuration: configuration, logger: application.logger)
        server[storage: Self.applicationKey] = application
        application.storage[Key.self] = server
        application.lifecycle.use(Lifecycle(server: server))
        mount(server, path: path)
        return server
    }

    /// The configured server. Traps if `configure()` hasn't been called.
    public var server: SocketIOServer {
        guard let server = application.storage[Key.self] else {
            fatalError("Socket.IO is not configured. Call app.socketIO.configure() first.")
        }
        return server
    }

    private func mount(_ server: SocketIOServer, path: String) {
        application.webSocket(
            PathComponent(stringLiteral: path),
            maxFrameSize: WebSocketMaxFrameSize(integerLiteral: server.configuration.maxPayload),
            shouldUpgrade: { req in
                let items = URLComponents(string: req.url.string)?.queryItems ?? []
                func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
                guard value("EIO") == "4", value("transport") == "websocket" else {
                    throw Abort(.badRequest, reason: "Only Engine.IO v4 over WebSocket is supported. Set transports: [\"websocket\"] on the client.")
                }
                return [:]
            },
            onUpgrade: { req, ws in
                var query: [String: String] = [:]
                for item in URLComponents(string: req.url.string)?.queryItems ?? [] {
                    query[item.name] = item.value ?? ""
                }
                let request = SocketIOUpgradeRequest(
                    headers: req.headers,
                    url: req.url.string,
                    query: query,
                    remoteAddress: req.remoteAddress?.description
                )
                // WebSocket callbacks must be installed on the socket's event loop.
                ws.eventLoop.execute {
                    let transport = VaporTransport(ws: ws)
                    let connection = server.accept(transport: transport, request: request)
                    // These closures own the connection; the close handler clears them to break the cycle.
                    ws.onText { _, text in connection.receive(text: text) }
                    ws.onBinary { _, _ in connection.receiveBinary() }
                    ws.onClose.whenComplete { _ in
                        ws.onText { _, _ in }
                        ws.onBinary { _, _ in }
                        connection.transportDidClose()
                    }
                }
            }
        )
    }
}

/// Wraps a Vapor `WebSocket` as a Socket.IO transport.
final class VaporTransport: SocketIOTransport, @unchecked Sendable {
    private let ws: WebSocket
    init(ws: WebSocket) { self.ws = ws }
    func send(_ text: String) { ws.send(text) }
    func close() { _ = ws.close() }
}

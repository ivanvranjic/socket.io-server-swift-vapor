# socket.io-server-swift-vapor

[Vapor](https://vapor.codes) 4 adapter for [socket.io-server-swift](https://github.com/ivanvranjic/socket.io-server-swift). Mounts a Socket.IO v4
endpoint (`/socket.io`) on a Vapor app's WebSocket router. Re-exports `SocketIOCore`, so one import is enough.

```swift
// Package.swift
.package(url: "https://github.com/ivanvranjic/socket.io-server-swift.git", .upToNextMinor(from: "0.1.0")),
.package(url: "https://github.com/ivanvranjic/socket.io-server-swift-vapor.git", .upToNextMinor(from: "0.1.0")),
.product(name: "SocketIOVapor", package: "socket.io-server-swift-vapor")
```

```swift
import SocketIOVapor

func configure(_ app: Application) async throws {
    let io = app.socketIO.configure()           // mounts /socket.io (path: "..." to change)

    io.use { socket in                          // auth middleware
        guard let token = socket.handshake.auth?["token"]?.stringValue else {
            throw SocketIOConnectError("unauthorized")
        }
        socket.setUserInfo("userId", try await verify(token, app))
    }

    io.onConnection { socket in
        socket.join("lobby")

        socket.on("chat", as: ChatMessage.self) { event, msg in
            socket.to("lobby").emit("chat", msg)          // everyone else in the room
            try event.ack?("delivered")                   // reply to client's ack callback
        }

        socket.onDisconnect { reason in /* cleanup */ }
    }

    io.namespace("/admin").onConnection { socket in /* ... */ }
}

// From a route handler:
app.post("announce") { req async throws -> HTTPStatus in
    req.socketIO.to("lobby").emit("announcement", "hello")
    return .ok
}
```

`socket.application` gives access to the Vapor `Application` (e.g. `socket.application.db`). The server shuts down
with the app. Clients must use the WebSocket transport only; see the core README for the full API and limitations.

## Tests

`Tests/Interop/run.sh` runs the core repo's JS client, Swift client and ping-timeout checks against `Examples/InteropServer`.

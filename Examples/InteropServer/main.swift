import SocketIOVapor
import Vapor

// Minimal server used by Tests/Interop/run.sh and as a usage example.

let app = try await Application.make(.detect())

var config = SocketIOConfiguration()
if let v = Environment.get("PING_INTERVAL").flatMap(Double.init) { config.pingInterval = v }
if let v = Environment.get("PING_TIMEOUT").flatMap(Double.init) { config.pingTimeout = v }
let io = app.socketIO.configure(config)

// Authenticate with the `auth` object the client sent.
io.use { socket in
    guard let token = socket.handshake.auth?["token"]?.stringValue, !token.isEmpty else {
        throw SocketIOConnectError("unauthorized")
    }
    socket.setUserInfo("user", token)
}

io.onConnection { socket in
    let user = socket.userInfo["user"] as? String ?? "?"
    socket.emit("welcome", ["user": user])

    socket.on("echo") { event in
        socket.emit("echo", event.args[0])
    }

    socket.on("sum") { event in
        let a: Int = try event.decode(at: 0)
        let b: Int = try event.decode(at: 1)
        try event.ack?(a + b)
    }

    socket.on("ask") { _ in
        let reply = try await socket.emitWithAck("question", "ping")
        socket.emit("asked", reply[0])
    }

    socket.on("join", as: String.self) { _, room in
        socket.join(room)
        socket.emit("joined", room)
    }

    socket.on("to-room") { event in
        let room: String = try event.decode(at: 0)
        let message: String = try event.decode(at: 1)
        socket.to(room).emit("room-msg", message)
    }

    socket.on("shout", as: String.self) { _, text in
        io.emit("all", text)
    }

    socket.on("kick") { _ in socket.disconnect() }

    socket.onDisconnect { _ in
        socket.to("r").emit("left", user)
    }
}

io.namespace("/admin").onConnection { socket in
    socket.emit("hello-admin", "admin")
}

try await app.execute()
try await app.asyncShutdown()

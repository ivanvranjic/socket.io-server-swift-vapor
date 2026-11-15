// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "socket.io-server-swift-vapor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SocketIOVapor", targets: ["SocketIOVapor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ivanvranjic/socket.io-server-swift.git", .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    ],
    targets: [
        .target(
            name: "SocketIOVapor",
            dependencies: [
                .product(name: "SocketIOCore", package: "socket.io-server-swift"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .executableTarget(
            name: "InteropServer",
            dependencies: [
                .target(name: "SocketIOVapor"),
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Examples/InteropServer"
        ),
    ]
)

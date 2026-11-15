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
        .package(path: "../socket.io-server-swift"),
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

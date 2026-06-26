// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Halosmith",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Halosmith", targets: ["Halosmith"])],
    targets: [
        .executableTarget(
            name: "Halosmith",
            path: "Sources/HoloForge"
        )
    ]
)

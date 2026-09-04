// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "encrypted-dns-profiles",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "generate",
            path: "Sources/generate"
        )
    ]
)

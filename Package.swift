// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aperture",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Aperture", targets: ["Aperture"])
    ],
    targets: [
        .executableTarget(
            name: "Aperture",
            path: "Sources/Aperture",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

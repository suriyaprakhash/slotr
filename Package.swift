// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Slotr",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Slotr", targets: ["Slotr"])
    ],
    targets: [
        .executableTarget(
            name: "Slotr",
            path: "Sources/Slotr"
        )
    ]
)

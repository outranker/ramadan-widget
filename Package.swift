// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RamadanMenuBarWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "RamadanMenuBarWidget",
            targets: ["RamadanMenuBarWidget"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RamadanMenuBarWidget"
        )
    ]
)

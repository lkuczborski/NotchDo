// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NotchDo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchDo", targets: ["NotchDo"])
    ],
    targets: [
        .executableTarget(
            name: "NotchDo",
            path: "Sources/NotchDo",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)

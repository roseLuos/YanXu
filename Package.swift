// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "YanXu",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "YanXuCore", targets: ["YanXuCore"]),
        .executable(name: "YanXu", targets: ["YanXuApp"]),
        .executable(name: "YanXuWidgets", targets: ["YanXuWidgets"]),
        .executable(name: "YanXuSelfTest", targets: ["YanXuSelfTest"])
    ],
    targets: [
        .target(name: "YanXuCore"),
        .executableTarget(
            name: "YanXuApp",
            dependencies: ["YanXuCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(
            name: "YanXuSelfTest",
            dependencies: ["YanXuCore"]
        ),
        .executableTarget(
            name: "YanXuWidgets",
            dependencies: ["YanXuCore"],
            swiftSettings: [
                .unsafeFlags(["-application-extension"])
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)

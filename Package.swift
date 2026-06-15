// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KeyboardSwitcher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "kbswitcher", targets: ["KeyboardSwitcher"]),
    ],
    targets: [
        .executableTarget(
            name: "KeyboardSwitcher",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "KeyboardSwitcherTests",
            dependencies: ["KeyboardSwitcher"]
        ),
    ]
)

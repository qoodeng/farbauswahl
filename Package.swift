// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Farbauswahl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Farbauswahl",
            path: "Sources/Farbauswahl",
            resources: [
                .copy("Resources/colornames.csv"),
                .copy("Resources/app.html"),
                .copy("Resources/preferences.html"),
            ]
        ),
    ]
)

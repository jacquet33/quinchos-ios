// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuinchosApp",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
    ]
)

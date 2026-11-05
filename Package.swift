// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownToPdf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MarkdownToPdf", targets: ["MarkdownToPdf"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownToPdf",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MarkdownToPdf"
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lyo",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(name: "Lyo", targets: ["Lyo"])
    ],
    dependencies: [
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0")
    ],
    targets: [
        .target(
            name: "Lyo",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk")
            ],
            path: "Sources",
            exclude: ["Resources/Info.plist", "Tests"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/GoogleService-Info.plist")
            ]
        ),
        .testTarget(
            name: "LyoTests",
            dependencies: ["Lyo"],
            path: "Sources/Tests"
        )
    ]
)

// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SolanaSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SolanaSwift",
            targets: [
                "SolanaSwift",
            ]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap.git", from: "1.1.0"),
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.12.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SolanaSwift",
            dependencies: [
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                "Starscream",
            ]
        ),
        // This test target isn't updated to reflect recent changes in the SDK
        /*
        .testTarget(
            name: "SolanaTests",
            dependencies: [
                "Solana",
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                "Starscream",
            ]
        )
         */
    ]
)

// swift-tools-version: 5.9
// Swift Package Manager manifest (vendored patch; upstream mic_stream ships
// CocoaPods only). Mirrors Flutter's plugin_swift_package_manager template.

import PackageDescription

let package = Package(
    name: "mic_stream",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "mic-stream", targets: ["mic_stream"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "mic_stream",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)

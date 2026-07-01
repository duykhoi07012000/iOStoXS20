// swift-tools-version:5.9
import PackageDescription

// FujiKit — lõi PTP/IP đẩy film recipe xuống Fujifilm X-S20 (port từ prototype-python,
// đã kiểm chứng trên máy thật). Dùng Network.framework (iOS 13+/macOS 10.15+).
let package = Package(
    name: "FujiKit",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "FujiKit", targets: ["FujiKit"]),
    ],
    targets: [
        .target(name: "FujiKit"),
        .testTarget(name: "FujiKitTests", dependencies: ["FujiKit"]),
    ]
)

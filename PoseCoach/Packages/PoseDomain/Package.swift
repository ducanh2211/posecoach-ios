// swift-tools-version: 5.9
// Tầng logic thuần của PoseCoach — đo đạc, chấm điểm, hướng dẫn, cổng kiểm ảnh mẫu.
// Không dependency nào. Khai báo thêm macOS để `swift test` chạy thẳng trên máy Mac.

import PackageDescription

let package = Package(
    name: "PoseDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PoseDomain", targets: ["PoseDomain"]),
    ],
    targets: [
        .target(name: "PoseDomain"),
        .testTarget(name: "PoseDomainTests", dependencies: ["PoseDomain"]),
    ]
)

// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DJCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "DJCore", targets: ["DJCore"])], targets: [.target(name: "DJCore", path: "Core"), .testTarget(name: "DJCoreTests", dependencies: ["DJCore"], path: "Tests")])

// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SleepCore", products: [.library(name: "SleepCore", targets: ["SleepCore"])], targets: [.target(name: "SleepCore"), .testTarget(name: "SleepCoreTests", dependencies: ["SleepCore"])])

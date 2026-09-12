// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "IntentCoverage",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "intentcoverage", targets: ["IntentCoverageCLI"])],
    dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.2")],
    targets: [
        .target(name: "IntentCoverageCore", dependencies: [.product(name: "SwiftSyntax", package: "swift-syntax"), .product(name: "SwiftParser", package: "swift-syntax")]),
        .target(name: "IntentCoverageGenerator", dependencies: ["IntentCoverageCore"]),
        .executableTarget(name: "IntentCoverageCLI", dependencies: ["IntentCoverageCore", "IntentCoverageGenerator"]),
        .target(name: "TaskFlowDomain", path: "Examples/TaskFlowDemo/Domain"),
        .testTarget(name: "TaskFlowDomainTests", dependencies: ["TaskFlowDomain"]),
        .testTarget(name: "IntentCoverageCoreTests", dependencies: ["IntentCoverageCore", "IntentCoverageGenerator"])
    ]
)

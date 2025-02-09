// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "DefaultApp",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/madmachineio/SwiftIO.git", branch: "develop"),
        .package(url: "https://github.com/madmachineio/MadBoards.git", branch: "develop"),
        .package(url: "https://github.com/madmachineio/MadDrivers.git", branch: "develop"),
        .package(url: "https://github.com/madmachineio/CFreeType.git", from: "2.13.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "DefaultApp",
            dependencies: ["SwiftIO", "MadBoards", "MadDrivers", "CFreeType",]),
    ]
)

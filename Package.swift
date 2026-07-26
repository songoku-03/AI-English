// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIEnglishTutor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AIEnglishTutor",
            targets: ["AIEnglishTutor"]
        ),
        .executable(
            name: "AIEnglishTutorApp",
            targets: ["AIEnglishTutorApp"]
        )
    ],
    targets: [
        .target(
            name: "AIEnglishTutor",
            dependencies: [],
            path: "Sources/AIEnglishTutor"
        ),
        .executableTarget(
            name: "AIEnglishTutorApp",
            dependencies: ["AIEnglishTutor"],
            path: "Sources/AIEnglishTutorApp"
        ),
        .testTarget(
            name: "AIEnglishTutorTests",
            dependencies: ["AIEnglishTutor"],
            path: "Tests/AIEnglishTutorTests"
        )
    ]
)

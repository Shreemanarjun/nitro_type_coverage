// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nitro_type_coverage",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "nitro-type-coverage", targets: ["nitro_type_coverage"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        // C/C++ bridge — SPM requires Swift and C++ in separate targets.
        // nitro headers (nitro.h, dart_api_dl.h …) are copied into include/
        // by `nitrogen link`, so no extra header search path is needed.
        .target(
            name: "NitroTypeCoverageCpp",
            path: "Sources/NitroTypeCoverageCpp",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-std=c++17"])
            ]
        ),
        // Swift implementation + generated bridge.
        .target(
            name: "nitro_type_coverage",
            dependencies: [
                "NitroTypeCoverageCpp",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/NitroTypeCoverage"
        ),
    ]
)

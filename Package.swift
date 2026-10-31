// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CGPUMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CGPUMonitor", targets: ["CGPUMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "CGPUMonitor",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)

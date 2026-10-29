// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "acemagic-s1",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "s1paneld",
            targets: [
                "acemagic-s1"
            ]
        )
    ],
    targets: [
        .systemLibrary(
            name: "CLibUSB",
            pkgConfig: "libusb-1.0",
        ),
        .target(
            name: "SysInfo",
            path: "Sources/SysInfo",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "acemagic-s1",
            dependencies: [
                .targetItem(
                    name: "CLibUSB",
                    condition: .when(platforms: [.linux])
                ),
                .targetItem(
                    name: "SysInfo",
                    condition: .when(platforms: [.linux])
                ),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx20
)

import ProjectDescription

let project = Project(
    name: "Example-iOS",
    settings: .settings(
        base: ["SWIFT_VERSION": "6.0"],
    ),
    targets: [
        .target(
            name: "Example-iOS",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.Example-iOS",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [:],
                ],
            ),
            buildableFolders: [
                "Sources",
                "Resources",
            ],
            dependencies: [
                .external(name: "NanoRedux"),
            ],
        ),
    ],
)

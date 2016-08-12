import PackageDescription

let package = Package(
    name: "BinaryJSON",
    dependencies: [
        .Package(url: "https://github.com/huawei-brice/CBSON.git", majorVersion: 1)
    ]
)

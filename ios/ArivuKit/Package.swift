// swift-tools-version: 6.0
//
// ArivuKit — everything on iOS that is not SwiftUI or UIKit.
//
// The rule that makes this package useful (leaves/MULTIPLATFORM.md): the product logic builds and its
// tests pass with NO Apple mobile SDK and NO native core present. `swift test` on a plain macOS box with
// Command Line Tools is the contract. Targets are split so that stays true:
//
//   ArivuCore   pure Swift. Prompt building, truncation, conversation JSON, gate, report, copy.
//               No native code, no UIKit, no SwiftUI. Fully tested here.
//   CArivuCore  a header-only module map over core/include/arivu/arivu.h. No `link` directive, so
//               importing it costs nothing; the app links the real static library through the
//               XCFramework that tools/ios/build_core.sh produces.
//   ArivuEngine the Swift wrapper over the C API. Compiles against the header alone.
//   ArivuChat   lifecycle + the chat state machine, the iOS twin of InferenceController/ChatViewModel.
//
//   CArivuStub  a fake core in C: every symbol in arivu.h, no llama.cpp, so the wrapper, the
//               lifecycle rules and the chat state machine are exercised for real on a machine that
//               has neither an iOS SDK nor a built engine. It is in NO product, so an app can never
//               link it next to the real core.
//
// spine: C8, C11
import PackageDescription

let package = Package(
    name: "ArivuKit",
    // Required because the copy catalogue lives in `Resources/en.lproj`: SwiftPM refuses a
    // localization directory with no default localization. Adding a language stays a data change —
    // drop `fr.lproj/Localizable.strings` in beside `en.lproj` (D-014).
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // STATIC, explicitly. Left to SwiftPM's default, an Xcode test bundle causes this product
        // to be built as a dynamic library, which then has to resolve `arivu_*` at its own link
        // time — and it cannot, because CArivuCore deliberately carries no `link` directive and the
        // real symbols come from ArivuCore.xcframework, which only the final binary links. The app
        // target linked fine and the test bundle failed with "Undefined symbols: _arivu_cancel,
        // _arivu_assistant_open …".
        //
        // Static also matches what ios/project.yml already asks of the framework: link it, do not
        // embed it, and add no dylib to load at launch for no benefit.
        .library(name: "ArivuKit", type: .static, targets: ["ArivuCore", "ArivuEngine", "ArivuChat"]),
    ],
    targets: [
        .target(
            name: "ArivuCore",
            resources: [.process("Resources")]
        ),
        .systemLibrary(name: "CArivuCore", path: "Sources/CArivuCore"),
        .target(name: "ArivuEngine", dependencies: ["ArivuCore", "CArivuCore"]),
        .target(name: "ArivuChat", dependencies: ["ArivuCore", "ArivuEngine"]),

        // Test-only. Never in a product: linking this beside the real core would duplicate every symbol.
        .target(name: "CArivuStub"),

        .testTarget(name: "ArivuCoreTests", dependencies: ["ArivuCore"]),
        .testTarget(name: "ArivuEngineTests", dependencies: ["ArivuEngine", "CArivuStub"]),
        .testTarget(name: "ArivuChatTests", dependencies: ["ArivuChat", "CArivuStub"]),
    ],
    swiftLanguageModes: [.v6]
)

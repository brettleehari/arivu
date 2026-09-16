# ios

Swift and SwiftUI over `/core`. See `leaves/engineering-ios.md` for the map, the sequence diagrams,
what is proven and what is not, and every remaining manual step.

```
ArivuKit/     SwiftPM package: everything that is not SwiftUI or UIKit.
              Builds and tests on macOS with no iOS SDK and no native core present.
App/          The app. SwiftUI, Info.plist, entitlements, privacy manifest, licences, assets.
project.yml   XcodeGen spec. The .xcodeproj is generated, never committed.
```

**Run the tests now, on any Mac:**

```sh
tools/ios/verify_macos.sh          # 94 tests, no Xcode needed
# or, on a Mac with Xcode:
cd ios/ArivuKit && swift test --no-parallel
```

**Build the app** (needs Xcode, CMake and XcodeGen):

```sh
tools/llama/fetch_llama.sh && tools/fetch_model.sh
tools/ios/build_core.sh            # → build/ios/ArivuCore.xcframework
tools/ios/sync_licences.sh
ARIVU_REPORT_EMAIL=you@example.com tools/ios/generate_project.sh
open ios/Arivu.xcodeproj
```

> **Nothing under `App/` has ever been compiled.** There was no Xcode on the machine it was written
> on. `ArivuKit` is verified; the app is careful and unproven. `leaves/engineering-ios.md` has the
> line-by-line table.

// The few things only a real bundle can answer.
//
// Everything about behaviour is tested in ArivuKit, on macOS, with `swift test`. What is left is
// what depends on the app having actually been built: that the model is where the app will look for
// it, that the privacy manifest shipped, that the licences shipped, and that the entitlement is on
// the binary. Those are cheap to check and expensive to discover at submission.
//
// UNVERIFIED: not compiled. Run on the Simulator or a device from Xcode.
//
// spine: C1, C3, C4

import ArivuCore
import ArivuEngine
import Testing
import Foundation
// The app target, for `AppInfo`. This bundle is hosted by Arivu.app and `AppInfo` is declared in
// ArivuApp.swift with no access modifier, so without `@testable` it is not visible here and the
// suite does not compile: "cannot find 'AppInfo' in scope".
@testable import Arivu

@Suite("The shipped bundle")
struct BundleTests {
    /// spine: C1 — one tap and it works. The model is in the app, not downloaded on first run.
    @Test func theModelIsInTheBundle() throws {
        let url = try #require(Bundle.main.url(forResource: Policy.modelResourceName,
                                               withExtension: Policy.modelResourceExtension),
                               "the model copy build phase did not run")
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
        #expect(size > 300_000_000, "the model in the bundle is \(ByteSize.si(size)); expected ~400 MB")

        // And it opens as fd + offset 0 + whole length, which is how the engine will take it.
        let open = try BundleModelSource().open()
        defer { open.close() }
        #expect(open.window.offset == 0)
        #expect(open.window.length == size)
    }

    /// spine: C3 — the privacy manifest is the App Store's version of the data-safety form.
    @Test func thePrivacyManifestShipped() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    /// spine: C4 — licences visible in-app, including the model weights.
    @Test func theLicencesShipped() throws {
        let index = try #require(Bundle.main.url(forResource: "index", withExtension: "txt",
                                                 subdirectory: "licenses"))
        let text = try String(contentsOf: index, encoding: .utf8)
        #expect(text.contains("Qwen3 0.6B model weights"))
        #expect(text.contains("llama.cpp"))
        #expect(text.hasPrefix("Notices (read first)"))
        // Every file the index names must be present, or a row opens onto nothing.
        for line in text.split(separator: "\n") {
            let file = String(line.split(separator: "|").last ?? "")
            #expect(Bundle.main.url(forResource: file.replacingOccurrences(of: ".txt", with: ""),
                                    withExtension: "txt", subdirectory: "licenses") != nil,
                    "missing licence text: \(file)")
        }
    }

    /// spine: C5 — the copy catalogue resolves from the real bundle, not only from the test harness.
    @Test func theCopyCatalogueResolves() {
        #expect(!Strings.catalogueSource.isEmpty)
        for key in StringKey.allCases {
            #expect(Strings.table[key.rawValue] != nil, "missing key in the shipped bundle: \(key.rawValue)")
        }
    }

    /// spine: C9 — the release check refuses the placeholder, but a Debug build can still carry it.
    ///
    /// `withKnownIssue`, not a bare `Issue.record`: the placeholder is expected until D-010 is
    /// decided, and a suite that is permanently red is a suite nobody reads. This keeps the run
    /// green while the blocker stays tracked where blockers belong — and the day the real address
    /// is set, Swift Testing reports the known issue as *unexpectedly passing*, which is the
    /// reminder to delete this wrapper. Red then means something again.
    @Test func theReportAddressIsConfigured() {
        #expect(AppInfo.reportEmail.contains("@"))
        withKnownIssue("the report address is still the placeholder (D-010)",
                       isIntermittent: false) {
            #expect(!AppInfo.reportEmail.contains("example.invalid"))
        }
    }

    /// The core is really linked, and it is the real one, not the test fake.
    @Test func theCoreIsLinked() {
        #expect(!ArivuEngine.coreVersion.isEmpty)
        #expect(!ArivuEngine.coreVersion.hasPrefix("stub"))
    }

    /// The number jetsam charges, read from the device rather than assumed.
    /// A Simulator reading is NOT representative and is labelled so.
    @Test func memoryCanBeMeasured() {
        // phys_footprint answers everywhere, including the Simulator and macOS.
        #expect(DeviceMemory.footprintBytes() != nil)

        // `os_proc_available_memory()` does NOT. It is compiled for iOS, so `#if os(iOS)` is true on
        // the Simulator, but the Simulator has no jetsam and returns nothing — this expectation
        // failed the first time this suite ever ran. "Not measured" is a first-class answer
        // everywhere else in this codebase and must be one here too, or the test asserts something
        // the platform never promised.
        if DeviceMemory.isSimulator {
            #expect(DeviceMemory.memorySource() == .unmeasured,
                    "no jetsam on the Simulator, so no ceiling may be applied from it")
        } else {
            #expect(DeviceMemory.availableBytes() != nil, "os_proc_available_memory() returned nothing")
            #expect(DeviceMemory.memorySource() == .probed)
        }
        print(DeviceMemory.summary())
    }
}

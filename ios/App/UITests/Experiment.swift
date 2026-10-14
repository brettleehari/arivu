// The D-051 experiment: does Metal pay for itself, and is the [2,4] thread clamp costing us?
//
// Both questions have been open on reasoning alone. D-051 refused Metal because offloading layers
// on Apple silicon moves the weights out of clean file-backed pages — which jetsam does not charge
// — into memory it does. That argument is correct for a 4 GB phone. Whether it is correct for a
// 12 GB one is a number nobody has taken. The thread clamp came from an Android cpufreq heuristic
// and was copied to iOS for C11 symmetry; on a 2P+4E phone it asks for 2 threads where PocketPal
// would use 4.
//
// WHY THIS RUNS ON A HANDSET AND NOT ON THE MAC. The whole question is about jetsam's accounting,
// which only exists on iOS. A tokens-per-second number from a laptop would answer the easy half
// and silently skip the half that matters.
//
// HOW IT MEASURES. It reads the numbers the app already shows: the per-reply line gives tokens a
// second, and About > How Arivu works gives the measured footprint. No new logging, and the test
// sees exactly what a user sees.
//
// Each cell is set by launch environment, which the shipped app can never set:
//   ARIVU_GPU_LAYERS  0 = CPU only (what ships), 99 = offload everything
//   ARIVU_THREADS     2 = the clamp on this phone, 4 = what PocketPal would use
//
// Run: xcodebuild test -scheme ArivuJourneys -only-testing:ArivuUITests/Experiment \
//        -destination 'platform=iOS,id=<udid>'
//      Build the core with ARIVU_METAL=1 first, or the GPU cells measure nothing.
//
// spine: C2, C11

import XCTest

final class Experiment: XCTestCase {
    private let prompt = "Explain in simple words why the sky is blue, in one short paragraph."
    private let replyTimeout: TimeInterval = 300

    /// One cell of the matrix. Returns what the app reported, or nil if it could not run — a
    /// configuration that cannot start IS a result, and the one D-051 predicts for the GPU cells.
    private func measure(gpuLayers: String, threads: String) -> (tps: String, footprint: String)? {
        let app = XCUIApplication()
        app.launchArguments = ["-ArivuUITestReset", "YES"]
        app.launchEnvironment["ARIVU_GPU_LAYERS"] = gpuLayers
        app.launchEnvironment["ARIVU_THREADS"] = threads
        app.launch()

        if app.buttons["welcome.start"].waitForExistence(timeout: 30) {
            app.buttons["welcome.start"].tap()
        }
        let input = app.textFields["chat.input"].firstMatch
        guard input.waitForExistence(timeout: 30) else { return nil }
        input.tap()
        input.typeText(prompt)
        app.buttons["chat.send"].firstMatch.tap()

        // Settled when a reply carries its own disclosure.
        let deadline = Date().addingTimeInterval(replyTimeout)
        while Date() < deadline &&
              app.buttons.matching(identifier: "chat.promptDisclosure").count == 0 {
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 1.0)
        }
        guard app.buttons.matching(identifier: "chat.promptDisclosure").count > 0 else { return nil }

        let line = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "tokens a second")).firstMatch
        let tps = line.exists ? line.label : "(no stats line)"

        // The measured footprint, read from the page that reads it from the system.
        var footprint = "(not read)"
        app.buttons["chat.about"].firstMatch.tap()
        if app.buttons["about.learn"].firstMatch.waitForExistence(timeout: 20) {
            app.buttons["about.learn"].firstMatch.tap()
            var scrolls = 0
            let row = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", "MB")).firstMatch
            while !row.exists && scrolls < 6 { app.swipeUp(); scrolls += 1 }
            if row.exists { footprint = row.label }
        }
        app.terminate()
        return (tps, footprint)
    }

    func testMatrix() {
        let cells: [(String, String, String)] = [
            ("CPU  · 2 threads  (what ships)", "0",  "2"),
            ("CPU  · 4 threads",               "0",  "4"),
            ("GPU  · 2 threads",               "99", "2"),
            ("GPU  · 4 threads",               "99", "4"),
        ]
        var report = ["", "=== D-051 MATRIX ==="]
        for (name, gpu, threads) in cells {
            let r = measure(gpuLayers: gpu, threads: threads)
            report.append("\(name.padding(toLength: 34, withPad: " ", startingAt: 0)) "
                          + (r.map { "\($0.tps) | footprint \($0.footprint)" }
                             ?? "DID NOT RUN — a configuration that cannot start is a result"))
        }
        report.append("====================")
        print(report.joined(separator: "\n"))
        // Never fails: this measures, it does not judge. The numbers go to a decision entry.
    }
}

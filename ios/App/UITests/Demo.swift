// A demo run for the App Review screen recording.
//
// Apple asked for "a screen recording captured on a physical device… beginning with launching the
// app and showing the typical user flow". The recording itself has to be made by a person — iOS
// screen capture is not something a test can start, and Control Centre is out of reach from
// XCUITest. What a test CAN do is drive the app through the flow on the real device, slowly and in
// the right order, so the person holding the phone only has to press record and watch.
//
// Paced deliberately. A UI test normally runs as fast as the app allows, which produces a video
// nobody can follow; every step here pauses long enough to be read on playback.
//
// What it cannot show, and why: aeroplane mode. Toggling it needs Control Centre, which no test can
// reach. If that moment is wanted — and it is the single most convincing ten seconds available,
// because it answers "which external services do you use" with a demonstration instead of a
// sentence — it has to be filmed by hand.
//
// Run: xcodebuild test -scheme ArivuJourneys -only-testing:ArivuUITests/Demo \
//        -destination 'platform=iOS,id=<udid>'
//
// spine: C1, C5

import XCTest

final class Demo: XCTestCase {
    private var app: XCUIApplication!

    /// Long enough to read on playback. A demo that moves at machine speed demonstrates nothing.
    private func beat(_ seconds: TimeInterval = 2.0) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "beat")], timeout: seconds)
    }

    func testRecordableFlow() {
        app = XCUIApplication()
        // Starts where a new user starts: the welcome, an empty chat, nothing configured.
        app.launchArguments += ["-ArivuUITestReset", "YES"]
        app.launch()
        beat(3)

        // 1. The welcome — what this is, in the first thing anyone sees.
        let start = app.buttons["welcome.start"].firstMatch
        if start.waitForExistence(timeout: 30) {
            beat(4)
            start.tap()
        }

        // 2. The empty chat. One screen, no account, no setup.
        let input = app.textFields["chat.input"].firstMatch
        guard input.waitForExistence(timeout: 30) else { return }
        beat(3)

        // 3. The work it is for.
        input.tap()
        input.typeText("Rewrite this politely: send me the report today, I have been waiting all week")
        beat(2)
        app.buttons["chat.send"].firstMatch.tap()
        waitForReply(count: 1)
        beat(4)

        // The second generation used to go here, and it is deliberately gone. XCUITest waits for
        // the app to be idle before each action, and a streaming reply never is — the runner hung
        // for 88 seconds, which on a recording is a frozen app. One reply is enough to show the
        // app works; the honesty about facts is in the written answer and on the About screen.

        // 5. The exact text the model was given. Nothing else on either store shows this.
        beat(3)
        let disclosure = app.buttons.matching(identifier: "chat.promptDisclosure").firstMatch
        if disclosure.exists {
            disclosure.tap()
            beat(3)
            app.swipeUp()
            beat(4)
            app.swipeDown()
            beat(2)
            disclosure.tap()
            beat(2)
        }

        // 6. The reporting mechanism Apple asked about — opened, then cancelled, nothing sent.
        let report = app.buttons.matching(identifier: "chat.report").firstMatch
        if report.exists {
            report.tap()
            beat(4)
            for label in ["Cancel", "Close", "Done"] {
                let b = app.buttons[label].firstMatch
                if b.exists { b.tap(); break }
            }
            beat(2)
        }

        // 7. The learning half: the model card, read live, and the tokenizer you can type into.
        app.buttons["chat.about"].firstMatch.tap()
        beat(3)
        let learn = app.buttons["about.learn"].firstMatch
        if learn.waitForExistence(timeout: 20) {
            learn.tap()
            beat(3)
            for _ in 0..<4 { app.swipeUp(); beat(1.5) }
            let field = app.textFields["learn.playground.field"].firstMatch
            if field.exists {
                field.tap()
                field.typeText("Arivu runs on your phone")
                beat(2)
                app.buttons["learn.playground.count"].firstMatch.tap()
                beat(5)
            }
        }
        beat(3)
    }

    private func waitForReply(count: Int) {
        let deadline = Date().addingTimeInterval(240)
        while Date() < deadline &&
              app.buttons.matching(identifier: "chat.promptDisclosure").count < count {
            beat(1)
        }
    }
}

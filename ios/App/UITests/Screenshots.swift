// App Store screenshots, captured from the running app (W-GTM-i4).
//
// NOT a journey, and kept apart from them on purpose: a journey fails when the app is wrong, and
// this one only ever produces pictures. They share a target because they need the same thing — the
// real app, the real model, driven from outside.
//
// WHY CAPTURE RATHER THAN DESIGN. Apple allows a framed, captioned marketing image here and most
// apps ship one. Arivu's whole claim is that it does what it says on a phone with nothing behind
// it, and a mocked-up screenshot is the first place that claim would quietly stop being true. Every
// image below is the app answering for real, on a real model, in the Simulator. What the reviewer
// sees is what a user gets.
//
// The states are the Android shot list (leaves/gtm/screenshot-shotlist.md) brought up to date for
// what iOS actually has now: conversations, per-reply cost, the prompt disclosure and the learning
// module did not exist when that list was written.
//
// Run: xcodebuild test -scheme ArivuJourneys -only-testing:ArivuUITests/Screenshots \
//        -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'
//      then tools/ios/export_screenshots.sh to pull the PNGs out of the .xcresult.
//
// spine: C1, C5

import XCTest

final class Screenshots: XCTestCase {
    private var app: XCUIApplication!
    private let uiTimeout: TimeInterval = 30
    private let replyTimeout: TimeInterval = 240

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ArivuUITestReset", "YES"]
        app.launch()
    }

    /// The keyboard stays up after typing and eats half the frame — it spoiled the first capture
    /// of the prompt disclosure twice, cutting the prompt off at the fold.
    ///
    /// TAPPING DOES NOT DISMISS IT. SwiftUI does not resign first responder because something else
    /// was tapped; ChatView dismisses on a DRAG, via `.scrollDismissesKeyboard(.interactively)`.
    /// So this drags. Where even that is unreliable, `relaunch()` below is used instead.
    private func dismissKeyboard() {
        guard app.keyboards.element.exists else { return }
        // Whichever scrollable container this screen happens to use. The chat is a ScrollView and
        // the learning page is a List, which XCUITest reports as a collection view — assuming the
        // first of those broke the capture on the learning page with "no matches for ScrollView".
        for container in [app.scrollViews.firstMatch, app.collectionViews.firstMatch,
                          app.tables.firstMatch] where container.exists {
            container.swipeDown()
            break
        }
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.0)
    }

    /// Restart the app with its conversations intact. The surest way to photograph a chat with no
    /// keyboard in it is to photograph one nobody has just typed into — and since the conversation
    /// is on disk, a relaunch gives exactly that. Dropping the reset argument is what keeps the
    /// messages (and stops the welcome coming back).
    private func relaunch() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ArivuUITestReset" || $0 == "YES" }
        app.launch()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout), "did not come back to the chat")
    }

    private func shot(_ name: String) {
        dismissKeyboard()
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private var input: XCUIElement { app.textFields["chat.input"].firstMatch }

    /// Type, check, and retype once if the keyboard helped.
    ///
    /// The Simulator's predictive bar put "The " on the front of a question, and that shipped into
    /// a listing image before anyone noticed. Turning the assists off (capture_screenshots.sh) is
    /// the first defence and it does not always take effect without restarting the device, so this
    /// verifies the field and repairs it rather than trusting a setting. A typo in a screenshot is
    /// seen by everyone who ever opens the App Store page, and nobody proofreads these.
    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
        guard let typed = field.value as? String, typed != text else { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count + 4)
        field.typeText(deletes)
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text,
                       "the keyboard keeps rewriting this; screenshots would ship with a typo")
    }

    private func replyCount() -> Int { app.buttons.matching(identifier: "chat.promptDisclosure").count }

    private func send(_ text: String) {
        let before = replyCount()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
        type(text, into: input)
        app.buttons["chat.send"].firstMatch.tap()
        let deadline = Date().addingTimeInterval(replyTimeout)
        while Date() < deadline && replyCount() <= before {
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.5)
        }
        XCTAssertGreaterThan(replyCount(), before, "no reply to photograph")
        dismissKeyboard()
    }

    func testCaptureAll() {
        // 1. The welcome — the first thing anyone sees, and the clearest statement of what this is.
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: uiTimeout))
        shot("01-welcome")
        app.buttons["welcome.start"].tap()

        // 2. The empty chat: one screen, nothing to configure.
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
        shot("02-empty")

        // 3. The work it is FOR. A real rewrite, with the per-reply cost underneath it.
        send("Rewrite this politely: send me the report today, I have been waiting all week")

        // 4. What it is BAD at, answered honestly. This is the shot that makes C5 a claim a
        //    reviewer can check rather than a sentence in the description.
        send("Who won the 2019 Cricket World Cup and what was the score?")

        // Both replies are in the conversation now, so restart and photograph it cold: no
        // keyboard, nothing focused, the screen a person actually returns to.
        relaunch()
        shot("03-rewrite")
        shot("04-hedges")

        // 5. The exact prompt. Nothing else on either store shows this.
        app.buttons["chat.promptDisclosure"].firstMatch.tap()
        _ = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "<|im_start|>"))
            .firstMatch.waitForExistence(timeout: uiTimeout)
        dismissKeyboard()
        // Scroll the opened disclosure up so the prompt itself is the subject of the picture
        // rather than a sliver under the message that prompted it.
        app.swipeUp()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.0)
        shot("05-prompt-disclosure")
        app.buttons["chat.promptDisclosure"].firstMatch.tap()

        // 6. The learning page, and 7. the part of it you use.
        app.buttons["chat.about"].firstMatch.tap()
        let learn = app.buttons["about.learn"].firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: uiTimeout))
        learn.tap()
        _ = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Qwen"))
            .firstMatch.waitForExistence(timeout: uiTimeout)
        shot("06-learn")

        let field = app.textFields["learn.playground.field"].firstMatch
        var scrolls = 0
        while !field.exists && scrolls < 8 { app.swipeUp(); scrolls += 1 }
        if field.exists {
            type("Arivu runs on your phone", into: field)
            app.buttons["learn.playground.count"].firstMatch.tap()
            _ = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "tokens"))
                .firstMatch.waitForExistence(timeout: replyTimeout)
            shot("07-try-it")
        }
    }
}

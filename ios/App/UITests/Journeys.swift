// Ten journeys, driven from outside the app exactly as a person drives it (W143).
//
// WHY THESE AND NOT MORE UNIT TESTS. The ArivuKit suites know that `delete(_:)` removes a
// conversation. They cannot know whether anybody can FIND the way to delete one — that question
// only exists on the other side of the glass, and it is the question "the navigation needs smooth
// UX" is actually asking. A journey here fails if a control is unreachable, unlabelled, or behind a
// gesture with no visible affordance, which is precisely the class of defect no unit test can see.
//
// THEY ARE SLOW AND THAT IS NOT A BUG. Several of them wait on a real reply from a real 1.7B model
// running on the Simulator's CPU. Mocking that away would mean testing a different app: the whole
// point of C1 is that the thing works end to end with nothing behind it, and a journey that stubs
// the model has stopped testing C1. They run in their own scheme, not in the unit-test loop.
//
// WHAT THEY MAY AND MAY NOT ASSERT. Controls are addressed by accessibility identifier (A11y), so
// rewording a button does not break a test that is not about wording. Where a journey IS about what
// a person reads, it asks the catalogue for the same string the app used, rather than keeping a
// second copy of the copy.
//
// spine: C1, C7, C8, C10

import XCTest

final class Journeys: XCTestCase {
    private var app: XCUIApplication!

    /// Long enough for a cold model map plus a short reply on Simulator hardware. Generous on
    /// purpose: a flaky timeout teaches people to re-run tests, which is how a real failure gets
    /// through one.
    private let replyTimeout: TimeInterval = 180
    private let uiTimeout: TimeInterval = 20

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // A clean device every time: journeys must not depend on what an earlier one left behind.
        // That also clears the welcome flag, so every journey starts where a new user starts —
        // which is now the welcome, not the chat (D-065). The nine journeys that are about the
        // chat step past it the way a person does, with one tap.
        app.launchArguments += ["-ArivuUITestReset", "YES"]
        app.launch()
        dismissWelcome()
    }

    /// One tap, and it is gone. If this ever needs two, C1 has been lost.
    private func dismissWelcome() {
        let start = app.buttons["welcome.start"].firstMatch
        if start.waitForExistence(timeout: uiTimeout) { start.tap() }
    }

    // MARK: - helpers

    private var input: XCUIElement { app.textFields["chat.input"].firstMatch }
    private var send: XCUIElement { app.buttons["chat.send"].firstMatch }

    private func type(_ text: String) {
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout), "the input never appeared")
        input.tap()
        input.typeText(text)
    }

    /// Send, and wait for the reply to SETTLE.
    ///
    /// This first waited for a Copy button to exist, which was wrong in a way that quietly broke
    /// four journeys: the user's own message has a Copy button too, so the wait returned the
    /// instant the sent message rendered and every assertion afterwards ran against a chat with no
    /// reply in it. The tests were not failing because the app was broken; they were failing
    /// because they never waited.
    ///
    /// The signal now is the one a person actually watches: Stop appears while Arivu writes and is
    /// replaced by Send when it stops. Waiting for Stop to go is waiting for the reply.
    @discardableResult
    private func sendAndWait(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let repliesBefore = replyCount
        type(text)
        XCTAssertTrue(send.isEnabled, "Send was disabled with text in the box", file: file, line: line)
        send.tap()

        // Wait for the reply itself to appear rather than for Stop to come and go: with the model
        // already mapped, a short reply can begin and end between two polls, and a test that
        // depends on catching a transient fails at random for reasons nobody can reproduce.
        let deadline = Date().addingTimeInterval(replyTimeout)
        while Date() < deadline && replyCount <= repliesBefore {
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.5)
        }
        XCTAssertGreaterThan(replyCount, repliesBefore,
                             "no reply arrived within \(replyTimeout)s", file: file, line: line)
        // And it has settled: Send is back, so nothing is still being written.
        XCTAssertTrue(waitUntilGone(app.buttons["chat.stop"].firstMatch, timeout: replyTimeout),
                      "still writing after \(replyTimeout)s", file: file, line: line)
        return true
    }

    /// Replies on screen, counted by the disclosure each one carries. Only Arivu's messages have
    /// one, so this counts replies and not turns.
    private var replyCount: Int {
        app.buttons.matching(identifier: "chat.promptDisclosure").count
    }

    /// Poll until an element is gone. `expectation(for:evaluatedWith:)` would read better, but it
    /// captures the test case across an isolation boundary and Swift 6 refuses it.
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.25)
        }
        return !element.exists
    }

    /// The way back to the conversation list on iPhone. Deliberately looked up the way a person
    /// finds it — the leading navigation control — rather than by identifier, because whether it is
    /// findable at all is part of what this suite is for.
    private func backToConversations() {
        let bar = app.navigationBars.firstMatch
        let back = bar.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: uiTimeout), "no way back to the conversations")
        back.tap()
    }

    // MARK: - 1. first run

    func test01_firstRunSendsAndAnswers() {
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout),
                      "the app did not open into a chat — C1 says one tap and it works")
        XCTAssertFalse(send.isEnabled, "Send should be disabled with an empty box")
        sendAndWait("Rewrite this politely: send me the report today")
        // The per-reply cost line, which is the thing that made the numbers honest.
        // The stats sit inside the reply's combined accessibility element, so they are read off
        // the message rather than looked for as a label of their own. "tokens in" is the spoken
        // form; "tok/s" is only what is printed.
        let spoken = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "tokens in"))
        XCTAssertGreaterThan(spoken.count, 0, "no per-reply stats under the reply")
    }

    // MARK: - 2. see what the model was actually given

    func test02_promptDisclosureShowsTheRealPrompt() {
        sendAndWait("Say hello")
        let disclosure = app.buttons["chat.promptDisclosure"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: uiTimeout),
                      "no way to see what was sent to the model")
        disclosure.tap()
        let chatml = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "<|im_start|>"))
        XCTAssertTrue(chatml.firstMatch.waitForExistence(timeout: uiTimeout),
                      "the disclosure opened but did not show the prompt")
    }

    // MARK: - 3. edit the instructions

    func test03_editingInstructionsChangesTheConversation() {
        sendAndWait("Say hello")
        app.buttons["chat.promptDisclosure"].firstMatch.tap()
        let edit = app.buttons["chat.editInstructions"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: uiTimeout), "no way in to the instructions")
        edit.tap()

        let field = app.textViews["promptEditor.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "the editor did not open")
        field.tap()
        field.typeText(" Always answer in exactly three words.")

        let save = app.buttons["promptEditor.save"].firstMatch
        XCTAssertTrue(save.isEnabled, "Save was disabled after an edit")
        save.tap()

        // The conversation now says it is not running the app's own wording.
        let badge = app.staticTexts["Edited instructions"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: uiTimeout),
                      "an edited conversation does not say so")
    }

    // MARK: - 4. put the instructions back

    func test04_resettingInstructionsClearsTheBadge() {
        sendAndWait("Say hello")
        app.buttons["chat.promptDisclosure"].firstMatch.tap()
        app.buttons["chat.editInstructions"].firstMatch.tap()
        let field = app.textViews["promptEditor.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout))
        field.tap()
        field.typeText(" Be a pirate.")
        app.buttons["promptEditor.save"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Edited instructions"].firstMatch
                        .waitForExistence(timeout: uiTimeout))

        // Back in, reset, save. The badge must go: there is no state to get stuck in.
        //
        // The disclosure stays open behind the sheet, so tapping it again would CLOSE it — which
        // is what this did, and the resulting failure read as "no way back into the instructions"
        // when the way back was there and the test had just shut the drawer on it. Open it only if
        // it is not already open.
        let editAgain = app.buttons["chat.editInstructions"].firstMatch
        if !editAgain.exists { app.buttons["chat.promptDisclosure"].firstMatch.tap() }
        XCTAssertTrue(editAgain.waitForExistence(timeout: uiTimeout),
                      "no way back into the instructions once they have been edited")
        editAgain.tap()
        let reset = app.buttons["promptEditor.reset"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: uiTimeout), "no way back to the standard wording")
        reset.tap()
        app.buttons["promptEditor.save"].firstMatch.tap()

        XCTAssertTrue(waitUntilGone(app.staticTexts["Edited instructions"].firstMatch),
                      "the badge survived a reset — the standard wording must leave no trace")
    }

    // MARK: - 5. start a second conversation

    func test05_newConversationStartsEmpty() {
        sendAndWait("First conversation")
        backToConversations()
        let new = app.buttons["conversations.new"].firstMatch
        XCTAssertTrue(new.waitForExistence(timeout: uiTimeout), "no way to start a conversation")
        XCTAssertTrue(new.isEnabled, "New conversation was disabled with a non-empty conversation")
        new.tap()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout),
                      "a new conversation did not land in the chat")
        XCTAssertEqual(replyCount, 0, "the new conversation was not empty")
    }

    // MARK: - 6. move between conversations

    func test06_switchingConversationsKeepsBothTexts() {
        sendAndWait("Remember apricot")
        backToConversations()
        app.buttons["conversations.new"].firstMatch.tap()
        sendAndWait("Remember blackcurrant")

        backToConversations()
        let rows = app.cells.count
        XCTAssertGreaterThanOrEqual(rows, 2, "both conversations should be listed")

        // Open the older one and check its words came back (spine: C7).
        let apricot = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "apricot")).firstMatch
        XCTAssertTrue(apricot.waitForExistence(timeout: uiTimeout),
                      "the first conversation is not findable by what was said in it")
        apricot.tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "apricot")).firstMatch
            .waitForExistence(timeout: uiTimeout), "the conversation did not reopen")
    }

    // MARK: - 7. delete one, visibly

    func test07_deletingAConversationIsDiscoverable() {
        sendAndWait("Delete me")
        backToConversations()
        let before = app.cells.count

        // The claim is that deletion is DISCOVERABLE — that there is a way a person can see, not
        // only a gesture they must already know. That is asserted directly.
        let edit = app.buttons["conversations.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: uiTimeout),
                      "there is no visible way to delete a conversation")
        XCTAssertTrue(edit.isHittable, "the visible delete affordance cannot be tapped")

        // The deletion itself goes through the swipe, which is the path that automates reliably;
        // edit mode's minus-then-confirm is the same `onDelete` underneath.
        let row = app.cells.element(boundBy: 0)
        XCTAssertTrue(row.waitForExistence(timeout: uiTimeout), "no conversation to delete")
        row.swipeLeft()
        let remove = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Delete")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: uiTimeout), "the swipe revealed no Delete")
        remove.tap()
        XCTAssertTrue(waitUntilGone(app.cells.element(boundBy: max(before - 1, 0))),
                      "the conversation is still listed after being deleted")
    }

    // MARK: - 8. take the words away

    func test08_copyConfirmsItself() {
        sendAndWait("Say hello")
        let copy = app.buttons.matching(identifier: "chat.copy").element(boundBy: 1)
        XCTAssertTrue(copy.waitForExistence(timeout: uiTimeout), "the reply has no Copy button")
        copy.tap()
        // iOS confirms nothing, so Arivu confirms itself (leaves/design.md §4). The button keeps
        // its identifier and changes its title, so this reads the title rather than hunting for a
        // different control.
        let deadline = Date().addingTimeInterval(uiTimeout)
        var sawCopied = false
        while Date() < deadline && !sawCopied {
            sawCopied = copy.label.localizedCaseInsensitiveContains("copied")
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.2)
        }
        XCTAssertTrue(sawCopied, "Copy gave no feedback that anything happened")
    }

    // MARK: - 9. stop it

    func test09_stopWorksMidReply() {
        type("Write a very long and detailed essay about the history of tea")
        send.tap()
        let stop = app.buttons["chat.stop"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: replyTimeout),
                      "Stop never appeared — C10 says it works at any moment")
        stop.tap()
        // The bubble gains the label that says who stopped it.
        let stopped = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "stopped")).firstMatch
        XCTAssertTrue(stopped.waitForExistence(timeout: uiTimeout),
                      "a stopped reply does not say it was stopped")
    }

    // MARK: - 11. the welcome, once and only once

    func test11_welcomeAppearsOnceAndCostsOneTap() {
        // setUp already dismissed it; prove it does not come back on a relaunch.
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ArivuUITestReset" || $0 == "YES" }
        app.launch()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout),
                      "the second launch did not go straight to the chat")
        XCTAssertFalse(app.buttons["welcome.start"].exists,
                       "the welcome came back — it is meant to be seen once")

        // And on a genuinely first run it IS there, with a way into the learning page beside it.
        app.terminate()
        app.launchArguments += ["-ArivuUITestReset", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: uiTimeout),
                      "a first run did not show the welcome")
        XCTAssertTrue(app.buttons["welcome.learn"].exists,
                      "the welcome does not offer the learning page")
        app.buttons["welcome.start"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout),
                      "one tap did not land in the chat")
    }

    // MARK: - 12. count your own sentence

    func test12_playgroundCountsWithTheRealTokenizer() {
        app.buttons["chat.about"].firstMatch.tap()
        let learn = app.buttons["about.learn"].firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: uiTimeout))
        learn.tap()

        let field = app.textFields["learn.playground.field"].firstMatch
        var scrolls = 0
        while !field.exists && scrolls < 8 { app.swipeUp(); scrolls += 1 }
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "no token playground on the page")
        field.tap()
        field.typeText("Arivu runs on your phone")

        let count = app.buttons["learn.playground.count"].firstMatch
        XCTAssertTrue(count.isEnabled, "Count was disabled with text in the box")
        count.tap()

        // The model has to map to answer, so this is allowed the same patience a reply gets.
        let result = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "tokens")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: replyTimeout),
                      "counting produced no answer")
    }

    // MARK: - 10. learn what it is

    func test10_learningPageIsReachableAndReadsLive() {
        sendAndWait("Say hello")  // so the model is mapped and the card can be read
        let about = app.buttons["chat.about"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: uiTimeout), "no way to About")
        about.tap()
        let learn = app.buttons["about.learn"].firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: uiTimeout), "no way to the learning page")
        learn.tap()

        // A real figure read from the model, not a typed-in one.
        let qwen = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Qwen")).firstMatch
        XCTAssertTrue(qwen.waitForExistence(timeout: uiTimeout),
                      "the model card did not render a model name")
        // And the way to the instructions from here. The page is long on purpose — it is a page
        // you read — so this scrolls for it the way a reader would.
        let editHere = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Edit these instructions")).firstMatch
        var scrolls = 0
        while !editHere.exists && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(editHere.waitForExistence(timeout: uiTimeout),
                      "the learning page does not offer the instructions it describes")
    }
}

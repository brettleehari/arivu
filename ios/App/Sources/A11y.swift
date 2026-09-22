// Test addresses for the controls a journey has to reach.
//
// These are accessibility IDENTIFIERS, not labels: nothing renders them and VoiceOver does not read
// them, so leaves/design.md §14 — "take every string by key; author none in Swift" — does not reach
// them. They are not copy. Labels, which ARE read aloud, stay in the catalogue where they belong.
//
// Why identifiers rather than matching on the visible text: the journeys would otherwise be a
// second copy of the catalogue, and every wording change would break tests that are not about
// wording. Where a test genuinely IS about what a user reads — "Copied" appearing after a tap —
// it asks for the string by key, from the same catalogue the app used.
//
// spine: C1
enum A11y {
    static let input = "chat.input"
    static let send = "chat.send"
    static let stop = "chat.stop"
    static let copy = "chat.copy"
    static let about = "chat.about"
    static let promptDisclosure = "chat.promptDisclosure"
    static let editInstructions = "chat.editInstructions"

    static let newConversation = "conversations.new"
    static let editConversations = "conversations.edit"

    static let promptField = "promptEditor.field"
    static let promptSave = "promptEditor.save"
    static let promptReset = "promptEditor.reset"

    static let learn = "about.learn"
}

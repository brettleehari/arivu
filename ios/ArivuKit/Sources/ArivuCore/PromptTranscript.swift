// What was actually sent to the model, rebuilt exactly.
//
// WHY THIS EXISTS. A user types "Explain AI and LLM in detail" — six words — and the line under the
// reply says 196 tokens in. Nothing in the app accounted for the other 190. That gap is not a
// detail: it is the single most misunderstood thing about a chat model, and Arivu is supposed to be
// the app that explains it (C5). Every turn carries the system prompt, the chat template's role
// markers, and as much of the conversation as still fits — and all of it is re-read from scratch on
// every single message, because the model has no memory between calls.
//
// WHY IT IS REBUILT RATHER THAN STORED. The obvious move is to save the prompt string with the
// reply. That is a copy of text the file already holds, growing quadratically — every reply would
// store the whole conversation up to that point — and two copies of one thing is an invitation for
// them to disagree. The prompt is a pure function of (system prompt, turns, where the window
// starts), and the only non-obvious input is where the window starts, because PromptBuilder drops
// old turns to fit. So that one number is recorded at send time and everything else is derived.
// No tokenizer is needed to rebuild it, which matters: opening a disclosure must never load a model.
//
// WHY THE HASH. A reply written under one system prompt and read back under another would be shown
// a prompt that was never sent — a page whose entire purpose is "this is exactly what went in"
// quietly lying. D-063 changed the prompt once already. So the system prompt's hash goes in with the
// reply, and a mismatch means the exact text is refused rather than approximated (spine: C5, C6).
//
// spine: C5, C6, C7

import Foundation

public enum PromptTranscript {
    /// Why the exact prompt cannot be shown. Never "here is roughly what it was".
    public enum Unavailable: Error, Equatable, Sendable {
        /// Written by a build from before this was recorded, or a reply that produced no tokens.
        case notRecorded
        /// The system prompt has changed since this reply was written (an app update).
        case systemPromptChanged
    }

    /// The exact bytes handed to the model for `reply`, or why they cannot be shown.
    ///
    /// `messages` is the conversation as it stands. Only the turns BEFORE the reply are used, which
    /// is what the model saw: nothing after it existed yet, and nothing before it can change, since
    /// Arivu has no message editing.
    public static func rebuild(reply: Message,
                               in messages: [Message],
                               systemPrompt: String = Policy.systemPrompt)
        -> Result<String, Unavailable> {
        guard let stats = reply.stats, let firstID = stats.contextFirstID else {
            return .failure(.notRecorded)
        }
        guard stats.systemPromptHash == hash(systemPrompt) else {
            return .failure(.systemPromptChanged)
        }
        guard let replyIndex = messages.firstIndex(where: { $0.id == reply.id }) else {
            return .failure(.notRecorded)
        }
        // The same filter `runSend` applies: an empty bubble is a placeholder, not a turn.
        let earlier = messages[..<replyIndex].filter { !$0.text.isEmpty }
        guard let start = earlier.firstIndex(where: { $0.id == firstID }) else {
            return .failure(.notRecorded)
        }

        var text = PromptBuilder.system(systemPrompt)
        for turn in earlier[start...] {
            text += PromptBuilder.render(Turn(id: turn.id, fromUser: turn.fromUser, text: turn.text))
        }
        text += PromptBuilder.assistantOpen
        return .success(text)
    }

    /// FNV-1a over UTF-8, 32 bits widened to fit JSON's number range without sign games.
    ///
    /// Not a security hash and not trying to be: it answers "is this the same prompt", where the
    /// alternatives are the prompt's length (which a reworded prompt of equal length defeats) or
    /// storing the prompt itself (840 bytes on every reply). Written out rather than taken from
    /// Foundation because `hashValue` is seeded per process and would differ between two launches
    /// of the same app — the one property this needs is that it does not.
    public static func hash(_ text: String) -> Int64 {
        var h: UInt32 = 2_166_136_261
        for byte in Array(text.utf8) {
            h ^= UInt32(byte)
            h = h &* 16_777_619
        }
        return Int64(h)
    }
}

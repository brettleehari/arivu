// The interactive half of the learning page (D-065).
//
// Every other section on that page tells you something. This one lets you find it out. The single
// most misunderstood thing about a model on a phone is that it does not read words, it reads
// tokens, and that there is a hard ceiling on how many of them fit — so you type into it and watch
// your own sentence become a number, against a bar that shows what the ceiling is already spending
// before you wrote anything.
//
// IT USES THE REAL TOKENIZER. Not a words-times-1.3 approximation. The whole page is built on
// "nothing here is typed in", and an interactive demo that lies is worse than a paragraph that
// tells the truth — someone would go away with a wrong number they had watched being computed.
//
// WHICH IS WHY IT COUNTS ON A TAP. `countTokens` maps the model if it is not mapped, a second or
// two of cold start. Counting on every keystroke would mean a learning page that loads a gigabyte
// because somebody typed a letter, and it would teach them something untrue about what this costs.
// The button is honest about the trade: you ask, it answers.
//
// spine: C5, C8

import ArivuChat
import ArivuCore
import SwiftUI

struct TokenPlayground: View {
    @ObservedObject var session: ChatSession
    private let profile = Profile.compact

    @State private var text = ""
    @State private var tokens: Int32?
    @State private var systemTokens: Int32?
    @State private var counting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(Strings.string(.learn_try_hint), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Palette.outline, lineWidth: 1))
                .accessibilityIdentifier(A11y.playgroundField)
                // A changed sentence has not been counted yet, and showing the previous answer
                // beside new text is the one thing this must never do.
                .onChange(of: text) { _, _ in tokens = nil }

            HStack {
                Button(Strings.string(counting ? .learn_try_counting : .learn_try_count)) { count() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(A11y.playgroundCount)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || counting)
                Spacer(minLength: 0)
                if let tokens {
                    Text(Strings.string(.learn_try_result, Int(tokens), words))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.onSurface)
                }
            }

            budget
        }
        .padding(.vertical, 4)
        .task { systemTokens = await session.systemPromptTokens() }
    }

    /// The context as a bar. Three real segments and the room that is left, so "2048 tokens" stops
    /// being a number on a spec sheet and becomes a thing with your sentence inside it.
    private var budget: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    segment(geo.size.width, systemTokens ?? 0, Palette.primary)
                    segment(geo.size.width, tokens ?? 0, Palette.onPrimaryContainer)
                    segment(geo.size.width, profile.replyReserveTokens, Palette.primaryContainer)
                    Rectangle().fill(Palette.surfaceVariant)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 14)
            .accessibilityElement()
            .accessibilityLabel(Strings.string(.a11y_learn_budget,
                                               Int(systemTokens ?? 0), Int(tokens ?? 0),
                                               Int(profile.replyReserveTokens), Int(profile.nCtx)))

            // A key, because four bands of colour with no names is decoration.
            VStack(alignment: .leading, spacing: 2) {
                key(.learn_try_key_system, systemTokens, Palette.primary)
                key(.learn_try_key_yours, tokens, Palette.onPrimaryContainer)
                key(.learn_try_key_reply, profile.replyReserveTokens, Palette.primaryContainer)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Palette.onSurfaceVariant)
        }
    }

    private func segment(_ total: CGFloat, _ value: Int32, _ colour: Color) -> some View {
        Rectangle()
            .fill(colour)
            .frame(width: max(0, total * CGFloat(value) / CGFloat(profile.nCtx)))
    }

    private func key(_ label: StringKey, _ value: Int32?, _ colour: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 9, height: 9)
            Text(Strings.string(label))
            Spacer(minLength: 4)
            Text(value.map { Strings.string(.learn_tokens_value, Int($0)) }
                 ?? Strings.string(.learn_try_unknown))
        }
        .accessibilityElement(children: .combine)
    }

    /// Whitespace-separated runs. Deliberately naive: the point of showing it beside the token count
    /// is that the two numbers DISAGREE, and a cleverer word count would blur that.
    private var words: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func count() {
        counting = true
        Task {
            let n = await session.countTokens(text)
            await MainActor.run {
                tokens = n
                counting = false
                if systemTokens == nil { Task { systemTokens = await session.systemPromptTokens() } }
            }
        }
    }
}

// How Arivu works — the learning page.
//
// Arivu is two products in one binary: an appliance nobody has to understand, and a way to
// understand what an appliance like this actually is. The chat screen is the first and must stay
// one screen (C1, C8). This is the second, one push inside About, where nobody meets it by
// accident and where wanting it is an explicit act.
//
// Why it is not a spec sheet. Every other local-model app shows "Cache Types: f16/f16" to people who
// already know what that means, which teaches nobody anything. Here each section says what the
// number IS and why this number was chosen, and the value follows the prose. C5 commits Arivu to
// being honest about what it is; this is that commitment with the arithmetic attached.
//
// Why nothing here is typed in. Every figure is read from the shipped profile or from the phone at
// this moment. A page of hand-written numbers is true on the day it is written and quietly wrong
// after the next profile change — which, for a page whose whole purpose is to teach, is worse than
// not having one.
//
// Apple's rules, applied rather than cited:
//   deference  a spec is content, so the chrome is the system's. An inset-grouped List is what iOS
//              uses for structured facts everywhere, and LabeledContent is the native pairing of
//              label and value — it gets Dynamic Type, right-alignment and the correct VoiceOver
//              reading ("Context, 2048 tokens") for free, where a hand-rolled HStack gets none.
//   clarity    monospaced digits so numbers do not jitter between rows; no decorative icons. Arivu's
//              own idiom is already "a word, not a gear" (ChatView), and a page about honesty is the
//              wrong place to start drawing chips and brains.
//   depth      a push from About, with the system's own back. No modal: this is a place you go, not
//              a thing that interrupts you.
//
// spine: C1, C4, C5, C8

import ArivuChat
import ArivuCore
import ArivuEngine
import SwiftUI

struct LearnView: View {
    @ObservedObject var session: ChatSession
    @State private var editingPrompt = false
    private let profile = Profile.compact

    init(session: ChatSession) { self.session = session }

    var body: some View {
        List {
            Section {
                Text(Strings.string(.learn_intro_body))
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }

            section(.learn_model_title, .learn_model_body) {
                row(.learn_model_name, Strings.string(.app_name) + " · " + profile.modelID)
                row(.learn_model_quant, Strings.string(.learn_model_quant_value))
                row(.learn_model_size, ByteSize.si(profile.modelBytes))
                row(.learn_model_licence, Strings.string(.learn_model_licence_value))
            }

            // What the file itself says. Read once the model is mapped; before that the page says
            // so rather than showing zeros that would read as measurements.
            section(.learn_card_title, .learn_card_body) {
                if let m = session.modelInfo {
                    row(.learn_card_arch, m.architecture)
                    row(.learn_card_params,
                        Strings.string(.learn_billions,
                                       String(format: "%.2f", Double(m.parameters) / 1_000_000_000)))
                    row(.learn_card_layers, "\(m.layers)")
                    row(.learn_card_heads, "\(m.heads)")
                    row(.learn_card_kv_heads, "\(m.kvHeads)")
                    row(.learn_card_sharing, Strings.string(.learn_sharing_value, Int(m.queriesPerKVHead)))
                    row(.learn_card_head_dim, "\(m.keyLength)")
                    row(.learn_card_embd, "\(m.embeddingWidth)")
                    row(.learn_card_vocab, "\(m.vocabulary)")
                    row(.learn_card_trained_ctx, Strings.string(.learn_tokens_value, Int(m.trainedContext)))
                    // The one number the page can check rather than report: the model's own shape
                    // predicts this, and so does the profile. They must agree.
                    row(.learn_card_kv_cost, ByteSize.si(m.kvBytesPerToken(q8_0: profile.kvQ8_0)))
                } else {
                    Text(Strings.string(.learn_card_unloaded))
                        .font(.footnote)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }

            section(.learn_context_title, .learn_context_body) {
                // Three tokens per four words is the rule of thumb the body explains; it is shown as
                // "about", never as a precise count, because it is not one.
                row(.learn_context_window,
                    Strings.string(.learn_tokens_approx, Int(profile.nCtx), Int(profile.nCtx) * 3 / 4))
                row(.learn_context_reply, Strings.string(.learn_tokens_value, Int(profile.maxReplyTokens)))
                row(.learn_context_reserve, Strings.string(.learn_tokens_value, Int(profile.replyReserveTokens)))
            }

            section(.learn_memory_title, .learn_memory_body) {
                row(.learn_memory_weights, ByteSize.si(profile.mappedBytes))
                row(.learn_memory_working, ByteSize.si(profile.footprintBytes))
                row(.learn_memory_peak, ByteSize.si(profile.estimatedPeakBytes))
                // The one live figure on the page: what the system says this process is costing now.
                // On a Simulator, and on macOS, nothing answers — so it says so rather than showing a
                // zero that would read as a measurement.
                row(.learn_memory_now,
                    DeviceMemory.footprintBytes().map { ByteSize.si($0) }
                        ?? Strings.string(.learn_memory_unmeasured))
            }

            section(.learn_speed_title, .learn_speed_body) {
                row(.learn_speed_threads, "\(DeviceMemory.performanceCoreCount())")
                row(.learn_speed_backend, Strings.string(.learn_speed_backend_value))
                row(.learn_engine_core, ArivuEngine.coreVersion)
            }

            // Why the processor and not the graphics chip. The trade is the whole memory argument,
            // and it is a property of the phone rather than of Arivu (D-051).
            Section {
                Text(Strings.string(.learn_metal_body))
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)
            } header: {
                Text(Strings.string(.learn_metal_title)).foregroundStyle(Palette.onSurfaceVariant)
            }

            // This section used to print the last reply's measurements, and that was the wrong
            // place for them. The numbers describe ONE reply, so by the time you had navigated
            // here to read them they described a reply you could no longer see. They now sit under
            // the reply they measure, in the chat, and this section explains what they mean —
            // which is the job a learning page can do that a chat line cannot.
            //
            // So this is the one section on the page with no live figures in it, deliberately. The
            // rows are definitions, in the order the line prints them.
            // The prompt, and the way in to changing it (D-064). It sits here rather than on the
            // chat screen for the reason the whole page sits here: wanting it has to be an explicit
            // act, or it is a setting (C8).
            section(.learn_prompt_title, .learn_prompt_body) {
                row(.learn_prompt_state,
                    Strings.string(session.usesCustomPrompt ? .learn_prompt_edited
                                                            : .learn_prompt_standard))
                Button(Strings.string(.prompt_edit_open)) { editingPrompt = true }
                    .foregroundStyle(Palette.primary)
            }

            section(.learn_speed_measured_title, .learn_speed_measured_body) {
                definition(.learn_speed_tokens_in, .learn_speed_tokens_in_body)
                definition(.learn_speed_tokens_out, .learn_speed_tokens_out_body)
                definition(.learn_speed_write, .learn_speed_write_body)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .navigationTitle(Strings.string(.learn_title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingPrompt) { SystemPromptEditor(session: session) }
    }

    /// A titled section: the explanation first, then the figures it explains. Prose before numbers,
    /// because the numbers are the part a reader cannot interpret on their own.
    private func section<Rows: View>(_ title: StringKey,
                                     _ body: StringKey,
                                     @ViewBuilder rows: () -> Rows) -> some View {
        Section {
            Text(Strings.string(body))
                .font(.subheadline)
                .foregroundStyle(Palette.onSurfaceVariant)
            rows()
        } header: {
            Text(Strings.string(title))
                .foregroundStyle(Palette.onSurfaceVariant)
        }
    }

    /// A term and what it means. NOT `row`: that one right-aligns a monospaced figure, which is
    /// right for "2048 tokens" and wrong for a sentence — a wrapped paragraph pushed to the trailing
    /// edge is unreadable. A definition is prose, so it reads left to right under its term.
    private func definition(_ term: StringKey, _ meaning: StringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Strings.string(term))
                .font(.body)
                .foregroundStyle(Palette.onSurface)
            Text(Strings.string(meaning))
                .font(.footnote)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// `LabeledContent`, not an HStack with a Spacer. It is the control iOS uses for exactly this,
    /// so it inherits the platform's alignment, Dynamic Type behaviour and — the part that matters —
    /// a VoiceOver reading that pairs the label with its value instead of announcing two unrelated
    /// strings.
    private func row(_ label: StringKey, _ value: String) -> some View {
        LabeledContent(Strings.string(label)) {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(Palette.onSurface)
                .multilineTextAlignment(.trailing)
        }
        .textSelection(.enabled)
    }
}

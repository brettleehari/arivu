// Editing the wording Arivu runs with, for one conversation (D-064).
//
// This is the one place in Arivu that looks like a setting, and it took a decision to add because
// C8 says there is no settings screen and R5 refuses personas. What makes it something else is that
// it is not a preference the app reads — it is the learning half of the product handing you the
// lever and letting you pull it. You have just been shown the exact bytes the model was given; the
// obvious next question is "what happens if that said something different?", and an app that shows
// you the prompt and will not let you touch it is teaching you to be a spectator.
//
// Three things keep it from becoming a settings screen:
//
//   per conversation   not global. Nothing you do here changes the next conversation, so the app a
//                      new user opens is the app C1 promises, every time.
//   nothing to restore the standard wording is always one tap away and is what every new
//                      conversation starts with. There is no state to get stuck in.
//   the safety sentences are not yours. They are shown, greyed, below the editor, and appended to
//                      whatever you write. There is no checkbox, because a checkbox is a thing that
//                      can be off (spine: C9).
//
// Apple's rules, applied: a sheet with Cancel and Save, because this is a self-contained edit with
// a decision at the end — the system's own shape for exactly that. Save is disabled until something
// changes, so the button tells you whether you have edited anything.
//
// spine: C5, C9, R5

import ArivuChat
import ArivuCore
import SwiftUI

struct SystemPromptEditor: View {
    @ObservedObject var session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .accessibilityIdentifier(A11y.promptField)
                        .font(.body)
                        .frame(minHeight: 200)
                        .overlay(alignment: .bottomTrailing) {
                            Text(Strings.string(.prompt_edit_chars,
                                                draft.count, Policy.customPromptMaxChars))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(overLimit ? Palette.error : Palette.onSurfaceVariant)
                                .padding(4)
                        }
                } header: {
                    Text(Strings.string(.prompt_edit_title)).foregroundStyle(Palette.onSurfaceVariant)
                } footer: {
                    Text(Strings.string(.prompt_edit_body))
                        .foregroundStyle(Palette.onSurfaceVariant)
                }

                // Shown, not hidden. A user who can see what is added is better informed than one
                // who is told a promise about it.
                Section {
                    Text(Policy.systemPromptSafetySuffix)
                        .font(.footnote)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .textSelection(.enabled)
                } header: {
                    Text(Strings.string(.prompt_edit_fixed_title))
                        .foregroundStyle(Palette.onSurfaceVariant)
                } footer: {
                    Text(Strings.string(.prompt_edit_fixed_body))
                        .foregroundStyle(Palette.onSurfaceVariant)
                }

                Section {
                    Button(Strings.string(.prompt_edit_reset)) {
                        draft = Policy.systemPromptBody
                    }
                    .accessibilityIdentifier(A11y.promptReset)
                    .disabled(isStandard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle(Strings.string(.prompt_edit_nav_title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.string(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.string(.prompt_edit_save)) {
                        session.setCustomPrompt(isStandard ? nil : draft)
                        dismiss()
                    }
                    .accessibilityIdentifier(A11y.promptSave)
                    .disabled(!changed || overLimit)
                }
            }
        }
        .onAppear {
            // Once: re-running this on every redraw would throw away what is being typed.
            guard !loaded else { return }
            loaded = true
            draft = session.customPromptBody ?? Policy.systemPromptBody
        }
    }

    /// The standard wording, whether it arrived by Reset or by typing it back in.
    private var isStandard: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
            == Policy.systemPromptBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var changed: Bool {
        draft != (session.customPromptBody ?? Policy.systemPromptBody)
    }

    private var overLimit: Bool { draft.count > Policy.customPromptMaxChars }
}

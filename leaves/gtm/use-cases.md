---
spine_version: 0.1
leaf: gtm
status: outline — not a commitment. Anything here that becomes a promise is a Spine change.
---

# What a pocket LLM is for

> "When computers were invented no one knew how everyone would use them."

So this is an outline, not a roadmap. It is organised by what a small model on a
phone is *structurally* good at, because that is what survives contact with a
4GB device and a 0.6B model.

## The one sentence

**A pocket LLM is a machine that operates on text you already have, in private, for free.**
It is not a knowledge source. The knowledge lives with the user, in the letter they
received, the form they must fill, the message they are about to send. The model
supplies fluency, structure and patience, not facts.

The nearest older object is not the encyclopaedia. It is the **letter-writer who used to
sit outside the post office**: someone literate, endlessly available, who turns what you
mean into what the official form expects, and reads back what the official letter says.

## Tier 1 — works today, in iteration-1 (text in, text out)

| Use | What the user does | Why it fits a small model |
|---|---|---|
| Rewrite for the reader | "Say this politely to my landlord" | Tone transfer is pattern work, not knowledge |
| Shorten / expand | Long message into an SMS; one line into a formal paragraph | Compression is bounded by the input |
| Explain a passage | Paste a contract clause, a school circular, a form's instructions | Comprehension of supplied text |
| Summarise | A long notice into three points | The source is present; nothing to recall |
| Draft from a brief | "Letter to parents: trip moved to Friday" | Boilerplate with the user's specifics |
| Fix and teach grammar | "Correct this and tell me what changed" | Correction plus a rule the user keeps |
| Restructure | Message into a to-do list, notes into headings | Structure extraction |
| Translate-ish | Draft in the local language, produce formal English | Qwen3 is multilingual; verify per language |
| Practise | "Ask me five questions about this passage" | Turns any text into study material |

**The private-by-default cases matter most here.** People will type things into an app
with no internet permission that they will never type into a cloud chatbot: a health
worry, a complaint about an employer, a letter to a family member, a first draft of a
resignation. Privacy is not a feature of the product, it is the category.

## Tier 2 — small additions, large gain (each is a Spine change)

1. **Share-target.** "Share to Arivu" from WhatsApp, the browser, a PDF reader.
   No new permission, no network. Probably the single highest value-to-cost item:
   it removes the copy-paste step that stands between a user and every Tier 1 use.
2. **Read a photo — the Gallery question.** Not today: the model is text-only, and the
   app asks for no storage permission. The offline path is **OCR, not vision**:
   Android's photo picker needs no permission, and an on-device text recogniser
   (ML Kit's bundled models, or Tesseract, both offline) turns the photo into text the
   model can already handle. That unlocks *photograph the notice / prescription label /
   form / textbook page, and explain it to me*, which for many users is the real job.
   Cost: recogniser size, a second model to keep offline, and script coverage — Latin is
   easy, Devanagari, Tamil, Arabic and CJK each need their own model. A true vision
   model on a 4GB phone is not yet realistic at permissive licences.
3. **Speak and listen.** Android's own text-to-speech is offline and free, which serves
   users who read slowly. Offline speech-to-text (Whisper-tiny class, Vosk) is heavier
   but turns the app into something usable by someone who cannot type comfortably.
   For low-literacy users this, not a bigger model, is the unlock.
4. **A real dictionary, not a remembered one.** "Pocket dictionary" is the right
   instinct and the wrong mechanism: a 0.6B model invents plausible definitions. Bundle
   an actual dictionary (WordNet-class data, permissive) for meanings, and let the model
   do what dictionaries cannot — usage in the user's own sentence, register, examples.
5. **Your own notes as the corpus.** Local retrieval over text the user saved, so the
   answer is grounded in their material rather than the model's memory. Currently
   refused (R4) and rightly so; it is the natural iteration-3.

## Tier 3 — where this goes if the constraint relaxes

- **Templates as a civic layer.** The forms that gate ordinary life — school admission,
  land records, bank KYC, benefit claims — are stable text. A bundled template pack plus
  a model that fills and explains them is a genuinely different product, and it works
  with no network at all.
- **Teacher's assistant.** Lesson notes, differentiated worksheets, marking prompts,
  parent letters, in the teacher's own language, on the teacher's own phone.
- **Health and agriculture extension workers.** People who work where signal ends, who
  carry printed guidance today, and who need it explained in a local language.
- **Shared-phone and sideloaded distribution.** One phone often serves a household;
  iteration-2's shareable APK spreads without data. That changes who the user is.

## What it is not for, and will not become

Facts, news, dates, figures, medicine, law, code. Anything the model must *recall*
rather than *transform* is where a small model fails most confidently. Every tier above
keeps the source text in the user's hands. That is the line, and the product's honesty
depends on holding it.

## What decides which of these gets built

Not taste — measurement. The benchmark (W02) and the writing eval (W04) say whether the
model can do Tier 1 well on the target phone. Nothing in Tier 2 is worth starting until
Tier 1 is demonstrably good, because each addition costs install size and memory on a
device that has neither to spare.

---
spine_version: 0.2
leaf: gtm
status: outline — not a commitment. Anything here that becomes a promise is a Spine change.
note: reconciled to Spine 0.2 (iOS in scope; C11 — capability follows the device profile, never the platform).
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

All nine of these are the same on an iPhone. None of them is a platform feature; if one ever is,
it belongs to a different product (`positioning.md`).

**The private-by-default cases matter most here.** People will type things into an app
with no internet permission that they will never type into a cloud chatbot: a health
worry, a complaint about an employer, a letter to a family member, a first draft of a
resignation. Privacy is not a feature of the product, it is the category.

## What changes when the device can carry more (C11)

Spine 0.2 makes the device tier a config object, not a code fork: a profile picks the model, the
context length and the thread count, and features gate on capability flags rather than on which
platform is running. That raises one question for this outline: **does a bigger profile add tiers?**

**No. It changes the size of the object, not the list of verbs.**

| A bigger profile buys | It does not buy |
|---|---|
| A longer piece of the user's text in one go — "explain this six-page notice" instead of "explain this paragraph". Context length is the binding constraint on Tier 1, not model size | Any new thing to ask for. The five verbs are the product |
| More reliable rewriting and summarising at the same tasks (the D-017 risk gets smaller, not different) | Facts, news, dates, numbers. A 4B model is still not a knowledge source, and the honesty screen (C5) does not change by one word |
| Room for a second small model beside the first — an OCR recogniser, a speech model — which is what actually unlocks Tier 2 | Permission to describe any of this in a store listing as a feature of some phones. See below |

Two consequences for this Leaf:

1. **Tier 1 is unchanged on every device we ship to.** Same verbs, same screen, same promise. What
   moves is how much text the user can paste before the context divider appears (C7), and how often
   the reply is good. Neither is a new use case; both are the same use case working better.
2. **Tier 2 is where C11 gets dangerous, and OCR is the test case.** A bundled text recogniser costs
   memory and install size, so it may only fit inside a larger profile. If the first device that can
   carry it happens to be an iPhone, we are one careless sentence away from "the iPhone app can read
   photos and the Android one cannot" — which is the fork `leaves/MULTIPLATFORM.md` warns about, not
   a profile. Before any Tier 2 item ships, run the six-question test in `positioning.md` §5, and in
   particular name the Android device that gets it under the same rule.

Two items in Tier 2 are *not* profile-gated at all, and that makes them the better first steps:
the **share-target** costs no memory and no model, so every device gets it or none does; and
**system text-to-speech** is provided by the operating system on both platforms. A bundled
**dictionary or template pack** is bounded by storage, not memory — and storage is the one resource
Amaka's 64 GB phone is not short of. Capability-by-device does not always mean capability-by-RAM.

**Store copy rule that follows from all of this:** a profile difference is never a listing feature.
No "on newer phones you also get…". The only honest public sentence about the ceiling is the one
already in the listing — *how much text Arivu can hold at once depends on your phone* — and the app
shows the divider when it is reached. Anything more invites the review we cannot answer: "why
doesn't mine do that?"

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
model can do Tier 1 well on the target phone. Those two runs decide it for **both** platforms, because
the eval runs on the host against the profile, not against a phone brand (`leaves/MULTIPLATFORM.md`). Nothing in Tier 2 is worth starting until
Tier 1 is demonstrably good, because each addition costs install size and memory on a
device that has neither to spare.

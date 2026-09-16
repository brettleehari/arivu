---
spine_version: 0.2
leaf: gtm
artifact: Positioning — one product, two platforms (Spine C11)
status: GTM position. Anything here that becomes a promise in a listing is a Spine change.
---

# Positioning — is iOS the same product?

Spine 0.2 withdrew R7 and added C11: *one product, two platforms; capability follows what the
device can carry, never which platform it runs on.* This Leaf says what that means for the
words we use in public, which is where the question actually gets decided.

`leaves/MULTIPLATFORM.md` states the risk precisely: two products sharing an engine is a fine
architecture; **two products pretending to be one produces a README that cannot say what the
app is.** Our only distribution channel is recommendation — teacher WhatsApp groups, a poster
on a school wall, a developer writing about the repo (`launch-plan.md`, all channels unpaid).
Recommendation carries exactly one sentence. A product that needs two sentences does not travel.

---

## The answer, in three lines

1. **Yes — iOS is the same product, because the promise is identical: your text, transformed, on
   your own phone, with nothing sent anywhere and nothing to configure.** That sentence is the
   product. It does not contain the word Android or the word iPhone.
2. **The iPhone is not the Spine's user, and we should stop pretending otherwise.** It is the
   recommender's phone, the reviewer's phone, the diaspora's phone — and it is where the second
   device profile (C11) gets built first, before an 8 GB Android phone inherits it.
3. **It stays one product for exactly as long as the difference between the two apps is a
   profile — how much model, how much context — and not a difference in what a user can ask for.**
   The day iOS gets a verb Android cannot have on equivalent hardware, we have two products, and
   we should admit it and give the second one its own name.

---

## 1. Who each platform actually reaches

The Spine's user is Amaka: a teacher in Enugu on a 4 GB Tecno, rationing a prepaid bundle. In
Nigeria, Indonesia, the Philippines, Brazil and Peru, iPhone owners are a minority of smartphone
users, and — this is the part that matters more — **an iPhone owner in those markets is usually
not the person whose problem the Spine describes.** They are not rationing data by the week.
Arivu's core value to them (it costs nothing to run and never touches the bundle) is real but
much less sharp.

> [U] We have no sourced market-share figure and we do not need one to make this call. If we ever
> publish a number, take it from StatCounter or IDC, name the country and the month, and put it in
> `leaves/NOTES.md` first. Never a round number from memory.

So the honest position is: **iOS does not serve the Spine's persona. It serves the people
standing around her, and it serves the product's future.** That is a reason, not an excuse, and
below is the argument in full.

## 2. What iOS is for (candidly)

Four ordinary reasons and one better one.

**a. The recommender's phone.** Amaka does not discover apps from ads. She hears about them from
the head teacher, the teacher-training college tutor, the NGO programme officer, the daughter in
Lagos with a salary job, the church WhatsApp admin. *An app the recommender cannot open is an app
the recommender does not recommend.* This is the strongest commercial reason and it is entirely
about word of mouth — our only channel.

> **[H] This rests on an assumption: that recommenders in our markets skew towards iPhones more
> than users do.** It is plausible and it is untested. It is also cheap to test — the closed-test
> recruiting in `launch-plan.md` already reaches teachers, head teachers and college tutors, so ask
> the recruiting contacts what phone they themselves use, and write the answer into
> `leaves/NOTES.md`. If it turns out the recommenders are on Android too, reason (a) weakens and
> reason (e) carries the case on its own.

**b. Press and write-ups.** Technology journalists and the people who write threads about
open-source tools are heavily on Apple hardware. Android-only means a story written from a press
release rather than from use. We do not pay for coverage (`launch-plan.md`), so the only currency
we have is that a writer can install it in two minutes.

**c. Diaspora reach.** Someone in Houston or London installs it, finds it useful for their own
letters, and sends the Play link home. The same person is also the one who pays for the phone at
the other end. This is a genuine install path for Wave A countries, not a vanity metric.

**d. Forkability (C4) is a claim we have to demonstrate.** "Permissive licences throughout, anyone
may fork it" is thin if the code has only ever been built one way. A second platform over the same
`/core` is the proof that the engine is the asset and the app is a thin shell over it.

**e. The better argument — iOS is where the profile mechanism gets its first real test.**
C11 says capability follows what the device can carry. Today there is one profile: Qwen3 0.6B,
2048 context, on a 4 GB phone. A profile mechanism with one profile is a theory. The first device
that can carry a second profile happens to be an iPhone — but the *long-run* customer for that
second profile is a mid-2020s 8 GB Android phone in the same markets, arriving in Amaka's
neighbourhood as second-hand hardware in two or three years.

So the real work iOS does for us: **it forces us to learn how to scale capability by device
without forking the product, at a moment when the blast radius is one app and one listing.**
If we get it right, an 8 GB Android flagship is a config row. If we get it wrong, we find out on
the platform whose users are least harmed by finding out.

That is what should be said out loud, including to Hari, instead of "iOS is for credibility."
Credibility is a side-effect. The mechanism is the point.

**And at launch there is nothing to explain away.** `leaves/architecture.md` §2.8 and §3.4 settle it:
iteration-1 ships exactly one profile, `compact` — Qwen3 0.6B at 2048 context — on every iPhone that
clears the minimum-version floor, with no increased-memory entitlement requested and the model bundled
in the app (§4.4). So the two apps launch as the *same model, same context, same screen*. The "is it
one product?" question is not a launch problem at all. It is a question about the second profile, and
the value of answering it now is that we answer it before anyone has shipped anything they would have
to take back.

**What iOS is NOT for:**
- It is not a revenue platform. There is no revenue (C1, free, no IAP).
- It is not a reason to build a bigger, cleverer Arivu for people who already have ChatGPT on
  their phone and an unlimited plan. That product exists, is not ours, and does not need us.
- It is not a reason to reopen any refusal in Spine §6 for one platform only.

## 3. The claim both apps make (word for word)

One sentence, identical on both stores, in the app, in the tour and in every talk:

> **Arivu works on text you give it — explain, summarise, shorten, rewrite, draft — running
> entirely on your own phone, with no internet, no account and nothing to set up.**

`leaves/architecture.md` §6 proposes making that mechanical: a release check (W71) asserting the
one-sentence description is byte-identical in `README.md`, both store listings and the About screen on
both platforms — "the day someone cannot make that sentence true in all five places, the product has
forked and the build says so." **GTM supports that, and the sentence above is this Leaf's candidate
text for it.** Two notes for whoever implements it: it must be the *same* sentence, not a similar one,
so agree the final wording with Design (the About screen has less room than a listing); and the check
belongs on the release path, not the commit path, because listing copy is edited in a console as well
as in the repo.

Three sub-claims travel with it, and all three must stay true on both platforms:

| Shared claim | True on Android because | True on iOS because |
|---|---|---|
| It runs entirely on the device | Model bundled in an install-time asset pack, llama.cpp over `/core` | Model is a plain file in the app bundle, same `/core`, same fd+offset loader |
| It sends nothing | **No `INTERNET` permission**; `tools/check_manifest.sh` fails the build if one appears (M5) | **No networking code**; open source; App Privacy "Data Not Collected" — see §7, and note this is a *weaker* proof |
| One screen, no settings, nothing to download after install | C1, C8: no picker, no parameters, no account | Same, by the same commitment — *and this is the one most at risk on iOS* |

And the honesty clause (C5), which is also shared and non-negotiable: **it is good at your text and
bad at facts.** An app that says that on one store and not the other is two products already.

**What is NOT shared, and must never be copy-pasted between the two listings:**

| Not shared | Android | iOS |
|---|---|---|
| The privacy *proof* | "no permission to use the internet" | "no networking code" + source + label (§7) |
| The device floor | RAM floor, Play Console exclusion rules (gate layer 2) | Minimum iOS version, which is a proxy for a chip; no device-exclusion catalogue |
| What happens on a phone we cannot serve | Gate screen + one button that opens Android's uninstall dialog (C6) | Gate screen that explains and stops. **iOS apps cannot offer to uninstall themselves** |
| Download size | ~400 MB (measured: AAB 399,118,011 B) | Not measured. Do not reuse the Android number |
| The word "cannot" | Correct | Forbidden. See §7 |

**Copy rule (apply at review time):** *any sentence that differs between the Play listing and the
App Store listing must name a platform difference that actually exists in the code.* If a sentence
differs because a writer felt like varying it, it is a bug in the listing.

## 4. The line that must not be crossed

**Arivu takes text the user gives it and gives text back. It has no memory beyond the conversation
in front of the user, no access to anything else on the device, and no ability to act.**

That is the line. It is the same line as "not an offline oracle" (SPINE §3) and the same line as
refusals R2 and R4. Crossing it does not make Arivu better; it makes it a different app with a
different audience, a different support burden and a different honest description.

`leaves/architecture.md` §6 reaches the same conclusion from the other side and puts it more
sharply than MULTIPLATFORM did: **"the tools fork it, the parameters do not."** Its four-question fork
test (device-reachable both ways · gracefully absent · same user · no new trust surface) is the
engineering-facing version of the test in §5 below; the two agree, and where they overlap, theirs is
the one with worked examples. This Leaf adds the two questions a listing forces you to answer.

Their caution is worth repeating because it is the one most likely to be misapplied by a marketer:
**C11 is violated by a rule that names a platform, never by a distribution that differs.** If more
iPhone owners happen to hold hardware that reaches a richer profile, that is the profile mechanism
working, not a fork. What would be a fork is a rule that says "on iPhone, do X".

Two clarifications C11 forces us to be precise about:

**A bigger model is not a crossing.** A 4 B model on a device that can carry it changes how well
the same requests come back. The user still asks for the same five things. Same product.

**A bigger capability list is a crossing.** `leaves/MULTIPLATFORM.md` sketches the profile as:

```
capabilities: [chat] | [chat, tools, longform]
```

GTM's position on that line: **`longform` is a profile. `tools` is a product boundary.** More
context means the same verbs applied to a longer document. Tool calling means the app now goes and
*does* things, which is R2, which is a different product with a different audience — and, on the
first platform where it shipped, an unanswerable question about why the Android app is "worse".

Recommendation: the capability list stays closed to `[chat, longform]` in iteration-1 and 2, and any
addition that changes *what the user can ask for* is a Spine amendment, argued once, for both
platforms. Proposed as **D-GTM-A** below.

## 5. The test: one product, or a fork?

Run this on any proposed feature, in order. It is written to be usable by someone who is not
holding the whole Spine in their head. Run it *alongside* the four-question test in
`leaves/architecture.md` §6, not instead of it: theirs decides whether the code forks, this one
decides whether the story does. A feature that passes theirs and fails this one is not safe to ship —
it is safe to build and unsafe to describe, which in a product distributed by word of mouth is the
same problem arriving later.

1. **The one-sentence test.** After this ships, does the sentence in §3 still describe the app on
   both platforms, unchanged? If describing the product now needs "…and on iPhone it also…", stop.
2. **The Amaka test.** Does it change *what she can ask for*, or only *how well, how fast, or how
   much text* the answer covers? Quality, speed and length are one product. New verbs are a new
   product.
3. **The profile test (C11).** Can it be switched on by a config row keyed to what the device can
   carry, with no new screen, no new setting and no user choice? If it needs a picker or an
   onboarding step, it fails C8 — redesign it until it needs none, or drop it.
4. **The equivalence test (C11).** Name the Android device that gets this feature under the same
   rule. If the only justification is "iPhones are fast" or "Apple gives us an API for it", it is a
   platform fork wearing a profile's clothes.
5. **The source-of-truth test (C5).** Does it move the app from *transforming text the user is
   holding* towards *answering from its own memory, from a bundled corpus, or from the network*?
   Any movement in that direction is Spine-level, whatever the engineering cost. (Retrieval over the
   user's own notes is the honest boundary case: the material is theirs, but the promise changes from
   "the text in front of you" to "your archive". Treat as a crossing until Hari says otherwise.)
6. **The listing test.** Write the store sentence for it now. If an honest sentence breaks the
   "What we must NOT claim" list in `store-listing.md`, the feature is not ready to be sold, which
   usually means it is not ready.

**Verdict rule.**

| Outcome | Meaning |
|---|---|
| All six pass | One product. Ships on both platforms, on every device whose profile can carry it, described identically |
| Fails 3 only | Not a fork — a design failure. Fix it until it needs no setting, or drop it |
| Fails 1, 2, 4 or 5 | **Fork.** Different app, different name, different listing, different audience. `/core` is shared; nothing else is |

**If the verdict is fork, the fork is allowed — but it must be honest.** A second product gets its
own name, its own one sentence, its own store record and its own privacy policy. What it may not do
is live inside Arivu's listing as a footnote about certain devices.

## 6. What a fork actually costs us (the GTM bill, not the engineering one)

Worth stating plainly, because the engineering cost of a second product looks deceptively small
(the core is shared) while the GTM cost is where it lands:

- **Two answers to "what is it?"** — and word of mouth carries one. This is the whole cost, and the
  rest is bookkeeping.
- Two listings, two names, two sets of screenshots, two review streams to read weekly (M6), two
  support inboxes or one inbox with two products' confusion in it.
- Two privacy policies, two data-safety / App Privacy declarations, two compliance checklists.
- Every feature request answered twice, and every "why doesn't mine do that?" review answered
  never, because the honest answer is about our roadmap and not about their phone.
- The honesty claim (C5) gets harder to hold: the app that says "I am small and bad at facts" is
  hard to sell next to a sibling that is neither.

None of that is an argument against ever forking. It is an argument for forking **deliberately, with
a name**, which is exactly what `leaves/MULTIPLATFORM.md`'s third caution asks for.

---

## 7. The privacy claim is weaker on iOS, and that is a GTM problem

### What actually changes

On Android, C3 is proof by absence. There is a permission an app must hold to touch the network;
Arivu does not hold it; the operating system enforces that; `tools/check_manifest.sh` fails the build
if any dependency adds one; the user can see it themselves on the Play listing under "App
permissions". Nothing in that chain depends on trusting us.

**iOS has no permission to withhold.** Any app may open a socket. There is no user-visible list that
shows Arivu is not allowed to. So the *structure* of the claim changes: on Android we can say
**cannot**; on iOS the true word is **does not**, and it has to be backed by receipts rather than by
the operating system.

This is a marketing problem before it is an engineering one, because the Android sentence is the
best line we own and the temptation to paste it across is enormous. **Do not paste it across.**
The moment we say "cannot" on iOS, the claim is false, one informed reader can say so publicly, and
the damage lands on the Android claim too — which is the one that was true.

### The honest iOS wording

Use this, or something that keeps all four moves (state it plainly · name the limit · give the
receipts · hand the user a test they can run):

> **Arivu does not use the internet.** No account, no sign-in, no server: the AI model is inside the
> app and runs on your iPhone.
>
> On iPhone, an app cannot prove this by giving up a permission — iOS has no such permission to give
> up. So here is what we can show you instead. Arivu's complete source code is public, and it
> contains no networking code. [*Once W-GTM-i1 ships, and only then, add: "Our release check fails if
> any is added."*] This app's privacy card on the App Store says **Data Not Collected**. And you can
> check it yourself in ten seconds: turn on Airplane Mode and use Arivu normally. Nothing changes,
> because nothing was ever being sent.

Shorter, for a screenshot caption or a poster:

> **No account. No server. No internet.** The model runs on your iPhone. The source is public, there
> is no networking code in it, and you can prove it to yourself with Airplane Mode.

**The receipts, in order of actual strength.** Say them in this order; do not lead with the label:

1. **The shipped binary links nothing that can reach the network.** `leaves/architecture.md` §5.5
   proposes `tools/check_ios_binary.sh` (`otool -L`, `nm -u`) failing the build if CFNetwork, Network,
   libcurl or the `URLSession`/`socket`/`connect`/`getaddrinfo` symbol set appear — and its key
   property for us is that **a sceptic can run the same check on the app they downloaded**. That is a
   stronger public claim than we had before this Leaf was written, and it is the closest iOS gets to
   Android's missing permission. Architecture is honest about the gap: a linked framework is
   capability, not use, so the check proves that the capability is absent, not that intent was good.
   *It does not exist yet.* Until it does, it is bracketed in the wording above and absent from
   `appstore-listing.md` and `privacy-policy.html`.
2. **Public source code** (D-035: `github.com/brettleehari/arivu`) — anyone may read it and see there
   is no network call.
3. **The user's own Airplane Mode test** — the only receipt that needs no trust and no expertise.
   For most readers this is the persuasive one, and it is the one the listing leads with.
4. **App Privacy "Data Not Collected"** — true and worth having, but it is a self-declaration Apple
   does not independently verify. Cite it last, never as the proof.

> **The precise limit of the iOS claim, stated so nobody overshoots it.** App Store binaries are
> re-signed and encrypted by Apple, so a user **cannot** verify that the shipped app was built from
> the source we published — the reproducible-build argument available on Android does not transfer.
> What a user *can* check on the downloaded binary is which frameworks and symbols it links (receipt 1
> above), because that information is not in the encrypted part. [U] Engineering should confirm that
> `otool -L` and `nm` remain readable on a store-delivered binary before we put this in public copy.
> So: we claim *no networking capability in the binary* and *no networking code in the source*. We do
> not claim *this binary is that source*.

### Words that must not cross from the Android copy to the iOS copy

Banned on the App Store listing, in iOS screenshots, in the iOS "what's new", and in any post about
the iOS app:

- "cannot go online", "it cannot use the internet", "no permission to use the internet"
- "Android does not let it send anything anywhere"
- "Private, because it cannot go online" (the Play description's heading)
- "a missing permission, not a promise" (the tour's line — it is true only on Android)
- Any phrasing that implies the operating system is enforcing the claim for us

Replacements: **does not · contains no networking code · runs entirely on your iPhone · check it
with Airplane Mode**.

**Be precise about the ban, so nobody over-applies it.** What is forbidden is the word *cannot*
attached to **Arivu's ability to reach the network**. The same word is correct and wanted elsewhere:
"on iPhone an app **cannot** prove this by giving up a permission" is the honest sentence that makes
the whole section work, and "if your iPhone **cannot** run Arivu well" is about the device. The test
is not the word; it is the subject of the verb.

And the reverse rule, which matters just as much: **do not weaken the Android copy to match iOS.**
Where a claim is provable, prove it. One product does not mean one lowest common denominator; it
means one promise, honestly evidenced on each platform.

### How the App Store listing phrases it

Concretely, in three places (drafted in full in `appstore-listing.md`):

1. **Description, privacy section** — the long wording above, in the app's plain-English register:
   states it, names the iOS limit in one clause, then the four receipts.
2. **App Privacy (the Console form, not free text)** — answer the questionnaire so the card shows
   **Data Not Collected**. That is Apple's own wording for the case where an app collects no data
   from the app; do not paraphrase it as "we collect nothing" in a way that implies Apple audited it.
   Report emails are sent by the user's mail app, on the user's explicit action, from their own
   address — the same reasoning as Play's D-025, applied to Apple's form. Compliance owns the answers.
3. **Support page / privacy policy URL** — the one place with room for the full argument, the build
   check, and the link to the source. The listing points there rather than arguing in the description.

---

## 8. PocketPal AI — the nearest comparable

PocketPal AI is the closest open-source comparable to Arivu: on-device LLM chat, iOS and Android,
permissively licensed. Everything below was read from its own public material on 2026-09-15 and is
cited; nothing here is a judgement about how well it works, because we have not evaluated it and
have no standing to say. **This section exists to sharpen our own position, not to argue against
theirs.**

Sources: repo `github.com/a-ghorbani/pocketpal-ai` (MIT), `pocketpal.dev`, its App Store and Play
listings, and its own `fastlane` listing copy in the repo.

**Deliberately not cited here:** their star ratings, review counts and download numbers. They are
public, but quoting a competitor's ratings in our own positioning document is how a fair comparison
turns into a sales sheet, and the number would tell us nothing we could act on.

### What it does well (from its own material)

- **Breadth of hardware and models.** A curated catalogue keyed to RAM band and SoC class, Hugging
  Face search and download in-app, GPU/NPU paths (Metal, OpenCL/Adreno, Hexagon), speculative
  decoding, KV-cache quantisation. It meets the enthusiast where they are. [V]
- **Expectation-setting in onboarding.** Its third onboarding screen reads: *"Pals on your phone are
  quick and private — but lighter than Cloud AI. Think pocket companion, not all-knowing oracle."*
  That is the same honesty C5 asks of us, and they say it before the user types anything. Worth
  noticing that the closest comparable reached the same conclusion independently. [V]
- **Reach and localisation.** Eleven locales, iPad support, tablets. Our English-only UI (D-014) is
  a real gap by comparison, and we should stop describing it as a neutral choice. [V]
- **Scope honesty in the listing.** Its Play copy states its floor out loud: *"You'll need 6GB+ RAM
  for smaller models, 8GB+ for the good stuff… Older or budget devices won't cut it."* Naming the
  floor in the listing is exactly what our compatibility gate does in code (C6). [V]
- **Features we do not have and have refused:** multimodal/vision, tool use, text-to-speech, personas
  and a persona marketplace, benchmarking with an opt-in public leaderboard, remote-server client
  mode, chat export/import, conversation search. [V]

### Who it is for

By its own words, *"People who stopped trusting the cloud with their conversations. People who want
AI that works on a plane, in a tunnel, off the grid. People who care about what runs on their own
hardware."* [V] The register is enthusiast-facing — *"Your AI. No one else's… This is AI you own —
not AI you rent"* — and the settings surface matches it: temperature, top-k, top-p, min-p, mirostat,
DRY penalties, GPU layers, batch and ubatch sizes, threads, flash attention, cache types, draft
models. [V]

That is a coherent product for a person who *wants* those controls. It is a different person from
Amaka.

### Where Arivu is deliberately different

| | PocketPal AI [V] | Arivu | Why |
|---|---|---|---|
| Getting to a first reply | Install, then 6 onboarding screens, then choose a tier (Quick / Balanced / Best) and **download a model** | Install, then chat. Nothing else exists | **C1**, and M1: "no screen other than chat" |
| The model | Catalogue keyed to device class; user picks; more can be added from Hugging Face | One model, bundled, never named as a choice | **C1, C8, R3** |
| Settings | Extensive, per-model and per-persona | None. Every setting is a decision already made | **C8** |
| Network | Android app declares `INTERNET`; needed at least once to fetch a model. Inference is offline | **No `INTERNET` permission at all** on Android; build fails if one appears | **C3, M5** |
| Download | App ~84 MB, then a model download (their low tier starts ≈229 MB; ≈484 MB for Qwen3 0.6B) | ~400 MB once, on Wi-Fi, then nothing, ever | We move the data cost to the one moment the user is on Wi-Fi |
| Device floor | Their copy: 6 GB+, 8 GB+ for larger models | 4 GB, enforced by gate layers 1–3, with a refusal instead of a slow app | **C2, C6** |
| Safety posture | Their copy: *"No content policies imposed by us. No behavioral guardrails we decided for you."* | An opinionated system prompt, an in-app Report path, and a stated limits screen | **C5, C9** and Play's AI-content policy |

The sharpest line of all: **their low tier offers the same model we ship — Qwen3 0.6B Q4_K_M. The
difference between the two products is not the model. It is everything around it, and mostly it is
the word "download".** For a user with Wi-Fi and 8 GB of RAM, that word costs nothing. For Amaka it
is the entire problem.

Second-sharpest: their listing says budget devices "won't cut it". **Those devices are our whole
market.** We are not competing for the same user; we are the app for the phone they have excluded,
and we should say so in our own terms, never in theirs.

### What we must NOT copy

Each of these is good design *for their user* and a defect for ours:

1. **A model manager, a model picker, a Hugging Face browser.** R3 and C8. If a model ever becomes a
   choice, C1's "one tap and it works" is gone and the listing has to explain a decision the user
   cannot make well.
2. **A parameter surface.** Temperature, top-p, GPU layers, context size. Every one is a question we
   have already answered; exposing it moves the blame for a bad reply onto the user.
3. **Onboarding screens.** Six screens before the first message is six chances to lose someone on a
   borrowed phone. Our first screen is the chat screen, with the limits printed on it.
4. **Any opt-in that goes online** — leaderboards, telemetry, feedback upload, marketplace, remote
   servers. On Android, a single one of these requires the `INTERNET` permission, and our best claim
   dies with it. There is no "small" exception to C3.
5. **"No content policies imposed by us."** That is a legitimate stance for a tool aimed at people
   who want control. It is not ours: C5, C9 and Play's AI-generated-content policy all point the
   other way, and our user is often reading a reply about their landlord, their health or their child.
6. **Their marketing register.** "AI you own, not AI you rent" is good copy for an audience that
   already has a subscription to compare it to. Our reader may be reading English as a second
   language and may never have had a subscription. Plain sentences, short words, no slogans.
7. **Naming a competitor in listing copy.** Their Play description names one. Our `store-listing.md`
   rule 7 forbids it, and Apple's metadata rules do too. Hold that line.
8. **The gap between marketing copy, the store privacy label and the technical privacy manifest.**
   Observed on the comparable: an App Store card reading "Data Not Collected", an iOS privacy
   manifest declaring an analytics data type, and a Play Data safety card saying personal info may be
   collected and shared. [V] There are plausible innocent explanations — an app with accounts, a
   marketplace and purchases genuinely has surfaces a chat app does not, and the three forms ask
   different questions. **We take no view on their filings.** The lesson we take is about ourselves:
   *our listing copy, our privacy policy, our Data safety form and our App Privacy card must be one
   document in four places, and any divergence is a release blocker.* On iOS this is doubled, because
   the label is the weakest of our four privacy receipts (§7) and it is the one a sceptic will check
   first. Add to the release checklist: read all four side by side before every submission, on both
   stores.

---

## 9. Proposed decisions and work items

Proposals only. This Leaf does not edit `decisions.yml` or `sequencing/workitems.yml`; the Decisions
and Sequencing Leaves own those files.

### Proposed decisions

| Ref | Question | Recommendation | Spine | Blocks |
|---|---|---|---|---|
| **D-GTM-A** | Is `tools` a profile capability or a product boundary? | Product boundary. The profile may vary model, context, threads. The capability list stays `[chat, longform]`; anything that changes *what the user can ask for* is a Spine amendment argued once for both platforms | C11, C8, R2 | Any iOS "big profile" work |
| **D-GTM-B** | What is iOS *for*, in one sentence in the Spine? | "iOS reaches the people who recommend Arivu, and is where the second device profile is proven before an 8 GB Android phone inherits it." Put it in SPINE §2 or beside C11, so it is not left implicit | C11 | — |
| **D-GTM-C** | Does the iOS privacy wording get its own approved text? | Yes — §7 above is the approved wording; the Android sentence may never be reused. Needs Hari's sign-off because it is the product's headline claim | C3 | App Store submission |
| **D-GTM-D** | Does an iOS release check exist that fails on networking code? | Required before we make the claim. Until it ships, the listing says "no networking code" (true, checkable in source) and **not** "our build check fails if any is added" | C3, M5 | App Store submission |
| **D-GTM-E** | Do the two listings mention each other? | No. Neither store listing names the other platform (Apple's metadata rules forbid it; Play gains nothing). The website and the repo carry both | C11 | Listing copy |
| **D-GTM-F** | Does a device profile difference ever appear in store copy as a feature? | No. Never "on newer phones you also get…". The only honest listing sentence is a ceiling: "How much text Arivu can hold at once depends on your phone" | C11, C6 | Listing copy |
| **D-GTM-G** | Is English-only still acceptable when the nearest comparable ships 11 locales? | Re-open D-014 with this as an input. Not a blocker for Wave A; it is a blocker for the claim that we serve these markets better than anyone | C1, C5 | Wave B |
| **D-GTM-H** | Apple age rating: answer honestly, then override higher? | Answer the questionnaire honestly on sensitive-content *frequency* (our own host probe shows the 0.6B model sometimes complies with a request it should refuse). Then decide the override separately, weighing discoverability against consistency with the Play 18+ target audience (D-024). Compliance + Hari | C9, C5 | App Store submission (`appstore-listing.md`) |
| **D-GTM-I** | iOS storefront availability | **All 175 storefronts from day one.** iOS's audience is recommenders, press and diaspora, who live outside the Play waves. Availability is not capability, so this is not a C11 divergence. Narrowable later without a new version | C11 | Submission |
| **D-GTM-J** | Do the two launches have to be the same day? | **Couple the announcement, not the release.** Play cannot hold a first release (verified); Apple can. Submit iOS with "Manually release this version" and release it on the day Play goes live. If iOS is not approved, Android ships alone — `leaves/MULTIPLATFORM.md`: never hold an Android fix for App Store review | C11 | Launch date |

### Proposed work items

| Ref | Work | Owner | Depends on |
|---|---|---|---|
| **W-GTM-i1** | **Already proposed by Architecture (§5.5) as `tools/check_ios_binary.sh`.** GTM's requirement on it is narrower: it must exist, and its exact guarantee must be written down, *before* any listing or policy sentence describes it. Also confirm `otool`/`nm` still read a store-delivered binary, since "you can check it yourself" is the claim | Engineering | Architecture §5.5 |
| **W-GTM-i2** | Measure the real App Store download size on a device, and the first-run time to first token on a 3–4 GB test iPhone. No iOS listing number is written until both exist | Engineering | iOS app |
| **W-GTM-i3** | Confirm what the iOS app actually does with the conversation file: private container, Data Protection class, excluded from iCloud backup. `privacy-policy.html` carries a placeholder block until this is answered | Engineering | iOS app |
| **W-GTM-i4** | Capture the iOS screenshot set on a real iPhone (the Android set cannot be reused; the incompatible-device screen has no Uninstall button on iOS) | Engineering + GTM | iOS app |
| **W-GTM-i5** | Four-way privacy consistency read before every submission: listing copy · privacy policy · Data safety (Play) · App Privacy (Apple) | GTM + Compliance | — |
| **W-GTM-i6** | A support page at the privacy-policy host: contact address, the three limits, how to delete your data, how to report a reply. Apple requires a support URL; a repo README is not one for a non-technical reader | GTM | D-010, D-022 |

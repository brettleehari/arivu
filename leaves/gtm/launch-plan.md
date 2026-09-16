---
spine_version: 0.2
leaf: gtm
artifact: Launch plan, first 90 days (v0.1.0) — Google Play, with the App Store sequenced against it
---

# Launch plan — first 90 days

Day 0 is the day the first bundle reaches the **internal testing** track. Dates are relative on purpose:
nothing starts until the entry gate below is green, and Engineering's on-phone work (W02, W08, W10, W21)
has no date yet.

Every channel here is unpaid. Nothing in any channel may say more than `store-listing.md` says, and
the "What we must NOT claim" list applies everywhere, including WhatsApp messages and talks.

## Verified rules this plan depends on (checked 2026-09-15)

| Rule | Source |
|---|---|
| Personal developer accounts created after 13 Nov 2023 must run a **closed test with at least 12 testers opted in continuously for at least 14 days** before applying for production access. A tester who opts out and back in restarts their 14 days. | Play Console Help 14151465 |
| Internal testing: up to 100 testers. | Play Console Help 9859348 |
| Privacy policy URL required even when no data is collected; public, non-geofenced, not a PDF; also a link or text inside the app. | Play Console Help 10787469, 9888076 |
| Apps distributed by unverified developers stop installing on certified devices in **Brazil, Indonesia, Singapore, Thailand from 30 Sep 2026**; global in 2027. | Android Developers Blog, June 2026 |
| AI chatbot apps must let users report offensive output "without needing to exit the app". | Play Console Help 13985936, 14094294 |

**Assumptions, not verified from here:** the developer account is a *personal* account created after
Nov 2023 (if it is an organisation account, the 12×14 rule does not apply, but keep a closed test anyway);
how long Google takes to review a production-access application; whether Android vitals shows data from
closed-test installs; whether a brand-new app can use a percentage staged rollout (we do not rely on it —
country-by-country release does the same job). **Now partly answered and worse than assumed:**
Play's managed publishing, which would let an approved release be published at a chosen moment,
explicitly "can't be used when publishing an app for the first time" (Play Console Help 9859654).
The same page gives review processing as "a few hours or up to seven days (or longer in exceptional
cases)" and advises a buffer of at least a week. So the Play go-live moment is Google's to choose,
not ours — which is what shapes the two-store section below.

## Two stores, one product — what "launch together" would actually require

Spine 0.2 puts iOS in scope (C11). The two stores have different gates, and the difference is
calendar time, not effort.

### The Apple rules this plan depends on (checked 2026-09-15)

| Rule | Source |
|---|---|
| **App Store review: "On average, 90% of submissions are reviewed in less than 24 hours."** Expedited review exists for a critical bug fix or an event, but Apple's own advice for an event is to schedule the release instead | `developer.apple.com/distribute/app-review/`; expedite request form `developer.apple.com/contact/app-store/?topic=expedite` |
| **An approved build can be held.** Choosing "Manually release this version" puts the approved app in **Pending Developer Release** until you release it. Apple emails a reminder if it sits there more than 30 days. The other options are "Automatically release" and "Automatically release… no earlier than [date and time]" | ASC Help, *Select an App Store version release option* |
| **Phased release is for updates only** — the section is literally "Phased Release for Automatic Updates". A first release has no percentage rollout | ASC Help, *Release a version update in phases* |
| **Availability: 175 countries or regions**, chosen before submission (All / Specific / Pre-Order), and **changeable at any time without a new version** — effective immediately, up to 24 hours to be visible | ASC Help, *Manage availability for your app on the App Store* |
| **TestFlight internal: up to 100 testers**, who must be App Store Connect users on the team with a qualifying role. Builds are testable for 90 days | ASC Help, *Add internal testers*; `developer.apple.com/testflight/` |
| **TestFlight external: up to 10,000 testers, and the first build of a version goes to Beta App Review.** A beta app description and beta review information are required | ASC Help, *Invite external testers*; *TestFlight overview* |
| **Apple Developer Program: USD 99/year.** Individual enrolment needs an Apple Account with 2FA and the applicant's legal name. Organisation enrolment needs a D-U-N-S number, a legal entity, a work email on the organisation's domain and a public website on it | `developer.apple.com/help/account/membership/program-enrollment/`; `developer.apple.com/programs/enroll/` |
| **D-U-N-S lead time:** "allow up to 5 business days to receive your number from D&B" plus "up to 2 business days for Apple to receive your information from D&B" | ASC Help, *D-U-N-S Number* |
| **Maximum app size: 4 GB uncompressed**, with a 500 MB cap on the executable's `__TEXT` sections. A bundled model is a resource, not executable text, so the cap that matters to us is the 4 GB one | ASC Help, *Maximum build file sizes* |
| **Google Play review processing: "a few hours or up to seven days (or longer in exceptional cases)"**, with Google's own advice to "include a buffer period of at least a week between submitting your app and going live" | Play Console Help 9859654 |
| **Play managed publishing cannot hold a first release:** "Your app must already be available to use Managed publishing. You can't use it when publishing an app for the first time." | Play Console Help 9859654 |

**Not verified, and not to be planned against:** how long Beta App Review takes (Apple publishes no
figure — the "90% in 24 hours" number is App Store review, not TestFlight); how long Apple's own
organisation identity verification takes; whether an expedite request is granted or how fast; and
whether the iOS cellular-download prompt still triggers at 200 MB (the number appears only in an
archived iOS 15 user guide; the current guide names none). The user-facing override —
Settings → App Store → App Downloads — does exist. Treat ~200 MB as a soft planning number and keep
it out of public copy.

### So what does "launch together" actually require?

**One store can wait and the other cannot.** That single asymmetry decides the whole plan:

- **Apple can hold an approved build indefinitely** in Pending Developer Release, and we press the
  button.
- **Play cannot hold a first release at all.** Managed publishing is explicitly unavailable for a
  first publish, so once the production release is approved, it goes live on Google's clock, not ours
  — somewhere between a few hours and seven days after submission, or longer.

| Meaning of "launch together" | What it requires | Verdict |
|---|---|---|
| **Same-day announcement** | Announce on the day the *second* store goes live. Costs nothing | **This is the target.** For unpaid word-of-mouth channels the launch *is* the announcement |
| **Same-day store availability** | Submit iOS with "Manually release this version"; let Play go live whenever Google approves it; release the held iOS build that same day | **Achievable, and only in that direction.** Trying to make Play wait for Apple is not a thing the Console supports |
| **Same-day readiness** | Both platforms built, measured and tested at once | **No.** `leaves/architecture/ios-port.md` calls this the expensive version, and it doubles the surface before a single number exists on a real phone of either kind |

**The rule that governs the rest** comes from `leaves/MULTIPLATFORM.md`: *"Independent release cadence
per platform. Never hold an Android fix for App Store review."* So: **couple the announcement, not the
release.** If iOS is approved in time, release it on the day Play goes live and announce once. If it
is not, Android ships, serves its users, and iOS gets its own smaller moment. Nothing about the "one
product" claim depends on a shared date; it depends on the two listings saying the same thing, which
is `positioning.md`'s job.

### The shape that costs least

```
Play:  internal upload → phone benchmark → closed test (12 x 14 days, dead calendar time) → production access → submit → live on Google's clock
Apple:                   └─ iOS build, iPhone measurements, TestFlight happen inside that window ─┘ → submit, "Manually release" → Pending Developer Release → release on the day Play goes live
```

`leaves/architecture/ios-port.md` makes the same point from the engineering side: the 14-day wait is
the cheapest iOS budget available, and by the time it ends, W02 and W04 have settled model, RAM floor
and quality for **both** platforms at once.

Two schedule hazards worth naming now:

- **Apple's first-build Beta App Review has no published turnaround.** If external TestFlight testers
  are wanted (and they are — see below), that review sits on the critical path with no number attached.
  Submit the first TestFlight build early in the 14-day window, not late.
- **Organisation enrolment is the long pole if Hari enrols as an organisation**: up to 5 business days
  for the D-U-N-S number, up to 2 more for Apple to receive it, then an unstated Apple verification
  step. Individual enrolment avoids all of that. This interacts with D-020 (the Play account question)
  and should be decided in the same sitting.

### Four things that are easy to get wrong here

1. **Do not skip a tester phase on iOS just because Apple does not require one.** Play forces 12
   testers for 14 continuous days; TestFlight forces nothing at all. The temptation is to submit an
   iOS build that three people have opened. Run the same closed test we run on Android — same
   feedback form, same questions — with whoever we can find on an iPhone. The requirement we would be
   dropping is Google's; the evidence we would be dropping is ours. Internal TestFlight (up to 100,
   team members only, no Beta App Review) covers the first week; external TestFlight (up to 10,000,
   first build reviewed) covers everyone else.
2. **Different store availability is not a product fork.** Play launches in waves (below) partly
   because of developer-verification enforcement and partly because of language. Neither applies to
   the App Store, and iOS's whole audience — recommenders, press, diaspora (`positioning.md` §2) —
   lives *outside* the wave countries. **Recommendation: all storefronts on iOS from day one**, which
   Apple allows and lets us change later without a new version. Availability is not capability, so
   C11 is untouched.
3. **The "stricter App Store scrutiny of on-device model output" claim is not verified.**
   `leaves/MULTIPLATFORM.md` states it and `leaves/architecture.md` §11 treats it as a pre-submission
   blocker. GTM's own reading of Apple's guidelines (2026-06-08 revision, checked 2026-09-15 — see
   `appstore-listing.md`) found **no** Apple rule requiring AI labelling, human review of generated
   output, or an AI report button. The moderation requirements in Guideline 1.2 turn on content being
   *shared between users*, which Arivu never does; 4.7 covers software not embedded in the binary,
   which our model is not. **What remains is reviewer discretion, which is real but is not a written
   rule.** Prepare for it — the Notes for App Review draft in `appstore-listing.md` exists for exactly
   this — rather than recording it as a blocker with no source. If anyone has a source, it belongs in
   the table above with a URL.
4. **The iOS minimum version is the only pre-install filter Apple gives us**, and it is Hari's
   decision (`leaves/architecture.md` §11). Setting it loosely means charging someone a large
   download to reach a wall — the outcome Play's device-exclusion rules exist to prevent, and the one
   M6 measures. There is no App Store device catalogue to fall back on.

### iOS entry gate (in addition to the Android gate below)

Nothing here starts a clock until the Android gate is green, because the iOS work is scheduled into
the Android wait, not ahead of it.

1. D-037 resolved yes (Spine 0.2 has withdrawn R7, but `decisions.yml` still carries D-037 as pending
   — the Decisions Leaf should close it).
2. Apple Developer Program enrolment complete, and a physical test iPhone in hand (Hari — **lead-time
   item, start it first**).
3. The iOS minimum version decided (Hari), and the runtime gate implemented with no uninstall button.
4. W-GTM-i2: real download size and first-reply time measured on that iPhone. No listing number
   before that.
5. W-GTM-i3: the conversation file's location, protection and backup exclusion confirmed, so the iOS
   blocks in `privacy-policy.html` can be published instead of deleted.
6. W-GTM-i4: the 6.9" screenshot set captured on the iPhone.
7. W-GTM-i5: the four privacy artefacts read side by side (listing, policy, Data safety, App Privacy).
8. App Privacy questionnaire answered so the card reads "Data Not Collected"; age-rating questionnaire
   answered honestly and the override question decided (D-GTM-H).
9. `appstore-listing.md` placeholders filled; the word "cannot" and the name of any other platform
   absent from every field.

## Entry gate (before Day 0)

All must be true. Owner in brackets.

1. D-001 package name resolved; D-010 report/contact address live and monitored (Hari).
2. Developer account identity verification complete (Hari) — required for Brazil and Indonesia this month.
3. W02 benchmark on the physical 4 GB phone recorded; W03 sets the RAM floor (D-009); the **Play Console
   device-exclusion rule (gate layer 2) is configured** before any track wider than internal (Engineering).
4. W21 passed: install bundle → airplane mode → first reply on the physical phone (Engineering).
5. Privacy policy hosted at a public URL (Hari: host choice). The in-app offline copy exists (About → Privacy policy); the HTML and in-app wording are reconciled (Hari).
6. Data safety form drafted: no data collected, no data shared (Compliance).
7. Per-reply Report sheet approved by Hari as a Spine scope change, and accepted by Compliance as meeting the AI-content policy's "without needing to exit the app".
8. Listing text, feature graphic, icon and the 4–5 screenshots chosen in `screenshot-shotlist.md` uploaded (GTM/Design/Engineering, W20). The shot 4 (Stop) recapture is optional.
9. D-017: W04 eval result read by Hari. If rewriting is unreliable, decide whether the listing, `about_good_body` and the "polite" example chip still name it.

## Phase 1 — Internal testing (Day 0 → Day 7)

- **Who:** the team plus up to ~10 people who own the phone we are built for (Helio G85 / SD680 class, 4 GB).
- **Do:** W18 — download Play-generated APKs from App bundle explorer; run `tools/zip_entry_offset.py` on the
  model pack (D-013). Install from Play on the physical phone; airplane mode; M1 check. Read the real
  download size shown by Play and correct "about 400 MB" in the listing if it is off by more than 10%.
- **Exit:** model loads from the Play-delivered pack on at least one real 4 GB phone; no crash in the first
  session on any tester phone; report button opens an email app with the D-010 address.

## Phase 2 — Closed testing (Day 7 → about Day 28)

- **Size:** recruit **20–25** testers so that 12 remain opted in for 14 unbroken days. Ask them not to leave
  the test early; explain why (opt-out resets their clock).
- **Who (the Spine persona, not friends of the team):** teachers and school-office staff with 4 GB Android
  phones in at least three countries from Wave A below, plus 2–3 testers in Brazil or Indonesia to exercise
  developer verification and non-English input. Recruit through people we already know in teacher
  networks; no incentives tied to ratings or reviews.
- **Low-data onboarding:** one text message (below 60 words) with the opt-in link and "install on Wi-Fi,
  about 400 MB". No video.
- **Feedback without telemetry:** Arivu sends nothing, so we ask. A 5-question form sent as plain text
  (reply in WhatsApp or email): phone model; did it install; did the first reply come (yes/no, and roughly
  how long it felt — their words, not a timer we publish); did it crash or freeze; one thing it helped with.
  Testers can also leave private feedback on the Play test listing.
- **Watch:** crash/ANR data in Android vitals if it appears for this track; incompatible-screen reports
  ("it said my phone can't run it" — which phone?); any harmful-output report emails.
- **Exit:** ≥12 testers × 14 continuous days; no open crash on a supported phone; zero reports of the app
  running on a phone below the floor without the incompatible screen; then **apply for production access**
  with honest answers from the form results.

## Phase 3 — Production (from production access, to Day 90)

Release by country, not by percentage.

| Wave | Countries | Why | Condition |
|---|---|---|---|
| **A** | Nigeria, Ghana, Kenya, Uganda, South Africa, Philippines | English is widely used for school and office text, so an English-only UI (D-014) is not a wall; prepaid data is the norm | Entry gate green; production access granted |
| **B** | Indonesia, Brazil | Large markets named in the Spine; developer verification enforced from 30 Sep 2026 | Account verified; D-017 eval shows acceptable replies in Bahasa Indonesia / Portuguese; D-014 decided (English UI accepted, or strings translated) |
| **C** | Peru, Colombia, Tanzania, and others matching the persona | Spanish/Swahili markets | Same as B for the relevant language |

**Compatibility gate is global, not per country.** Choosing countries does not replace layer 2: the RAM
exclusion rule must be in place before Wave A, and any device model that shows up in slow/crash reviews is
added to the exclusion list, not argued with.

## M6 on two stores

M6 (Spine: fewer than 5% of reviews citing slow/crash/doesn't work, first 90 days) was written for
Play. It applies to the App Store too, with three differences worth writing down before the first
review lands:

- **Per storefront, and fewer of them.** App Store ratings are shown per storefront, and an app with
  a small install base gets very few. The "below 40 total reviews, report the count, not a
  percentage" rule matters more here, not less.
- **No device-exclusion lever.** On Play, a bad review from an underpowered phone is answerable by
  adding the device to the exclusion list. On the App Store there is no catalogue; the only levers are
  the minimum iOS version (a new submission) and the runtime gate. So an iOS "it's slow" review is
  evidence that the **minimum version is wrong**, which is a slower and more expensive fix. Watch the
  first ten closely.
- **One table, two columns.** Keep a single weekly M6 record covering both stores rather than two.
  One product, one metric — and if the two platforms ever diverge sharply, that is itself the signal
  worth having.

## M6 — watching "slow / crash / doesn't work" reviews

Target (leaves/SPINE.md M6): **fewer than 5% of reviews** in the first 90 days of production.

- **Owner:** GTM Leaf. **Cadence:** weekly, same weekday, Play Console → Ratings and reviews.
- **Count:** every review in production countries since release (all star levels). A review counts toward
  M6 if it says the app is slow, crashes, freezes, closes, hangs, will not start, or "doesn't work", in any
  language. Keyword first pass (`slow, crash, freeze, hang, not working, doesn't work, stopped, lento, trava,
  não funciona, no funciona, lambat, macet, tidak bisa, error`), then **read every review** — keywords miss
  things and catch false hits ("slowly explained" is not slow).
- **Record** (a table in this Leaf, one row per week): total reviews, M6 reviews, %, device models named
  in M6 reviews, Android vitals crash and ANR rates versus Play's bad-behaviour thresholds as shown in Console.
- **Small numbers:** below 40 total reviews, report the count, not a percentage, and read each one.
- **Triggers:**
  - Any week with M6 above 5% and at least 20 reviews → Engineering checks vitals by device; propose a
    decision to raise the RAM floor or exclude device models (C2, C6).
  - Any review saying "it runs but very slow" on a phone *above* the floor → evidence that D-009 is too low.
  - Any crash on a supported phone → work item, MVP slice.
- **Reply to reviews** plainly, in the reviewer's language where we can, without promises we cannot keep.
  If the phone is below the floor, say so and thank them. Never ask for a rating change.
- **Not an M6 fix:** asking happy users for reviews to dilute the percentage. That hides the signal the
  metric exists for, and incentivised ratings break Play policy.

## Channels for offline and low-data users (unpaid)

1. **Teacher networks** — the persona is a teacher. School WhatsApp groups, teacher-training colleges,
   subject associations, head-teacher meetings. Asset: a 60-word text message plus one image under 150 KB.
2. **Install on Wi-Fi days** — schools, libraries and community tech hubs that already have Wi-Fi: "bring
   your phone, install once on our Wi-Fi, use it at home." Asset: a one-page A4 poster (print-friendly, black
   and white safe) with the Play link as a QR code and the three limits from `about_bad_body`.
3. **Open-source and developer communities** — the repo, a plain write-up of how it works offline (the
   Architecture Leaf is the source), local developer meetups. Forkability (C4) is the message there.
4. **Local-language tech press and creators** — send the tour and the listing; offer no payment or gifts.
5. **Word of mouth by copy-paste** — people share replies they got from Arivu; nothing to build.

Not in iteration 1: phone-to-phone APK sharing, F-Droid, paid ads, influencer payments, referral rewards.

**Two-platform note on channel assets.** Every asset here — the 60-word message, the A4 poster, the
talk — describes *the app*, not a platform. Keep one set. Where a store link is needed, put both links
on the page the QR code points at, never in the copy, because copy that says "also on iPhone" is copy
that has to be maintained twice and is forbidden inside the store listings themselves (Apple Guideline
2.3.10; `positioning.md` §3).

**Low-data asset texts (claims match the listing):**

> Arivu helps you rewrite, shorten, explain and summarise text on your phone, with no internet. The AI
> model is inside the app, so install it once on Wi-Fi (about 400 MB). No account. It is not good at facts,
> news or numbers — check anything important. Needs a 64-bit Android 11+ phone with about 4 GB memory.
> [PLAY_LINK]

(57 words.)

## 90-day calendar at a glance

| Days | What | Metric / evidence |
|---|---|---|
| 0–7 | Internal testing, W18 alignment check, real download size | M1 on physical phone, M5 via check_manifest |
| 7–28 | Closed test ≥12 × 14 days, feedback form, apply for production | Tester form table, vitals if present |
| ~28–35 | Production Wave A | Weekly M6 table starts |
| ~35–60 | Wave B if its conditions are met | M6 per country |
| 60–90 | Wave C if met; review M6 trend; propose Spine inputs (real user quotes, with permission, replace the hypothesised §1 quotes) | M6 at day 90 of production |

### The iOS track, laid over the same calendar

| Days | What | Gate |
|---|---|---|
| before 0 | Apple Developer Program enrolment started and a test iPhone bought (**Hari — longest lead time on either platform, especially if enrolling as an organisation**) | — |
| 0–7 | iOS build over `/core`; `compact` profile; first physical-iPhone measurements into `leaves/NOTES.md` (W81, W-GTM-i2) | Android internal testing is running in parallel |
| 7–14 | Internal TestFlight (team only, no Beta App Review). First external TestFlight build submitted **early**, because Beta App Review has no published turnaround | iOS screenshots (W-GTM-i4), listing placeholders filled |
| 14–28 | External TestFlight with the same tester questions Android uses — not fewer, just because Apple asks for none | W-GTM-i3 and W-GTM-i5 complete |
| ~28 | Submit to App Store with **"Manually release this version"**. 90% of submissions are reviewed in under 24 hours on average | Approved build waits in Pending Developer Release |
| the day Play goes live | Release the held iOS build; announce once, both platforms | If iOS is not approved yet, Android ships alone and iOS follows. Never the reverse |

Availability on the App Store: **all storefronts**, unlike Play's waves — see "Four things that are
easy to get wrong", point 2. It can be narrowed later at any time without a new version.

The 90-day M6 window is measured from the first production release, so it runs past Day 90 of this plan.

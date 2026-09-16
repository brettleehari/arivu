---
spine_version: 0.1
leaf: gtm
artifact: Launch plan, first 90 days (v0.1.0)
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
country-by-country release does the same job).

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

## M6 — watching "slow / crash / doesn't work" reviews

Target (SPINE.md M6): **fewer than 5% of reviews** in the first 90 days of production.

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
| 60–90 | Wave C if met; review M6 trend; propose Spine 0.2 inputs (real user quotes, with permission, replace hypothesised §1 quotes) | M6 at day 90 of production |

The 90-day M6 window is measured from the first production release, so it runs past Day 90 of this plan.

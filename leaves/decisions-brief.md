---
spine_version: 0.2
leaf: decisions/brief
source: leaves/decisions.yml (59 entries — 56 pending, 2 resolved by Hari, 1 superseded by the Spine bump)
prepared: 2026-09-16
---

# Decisions brief for Hari: one sitting

Answer each with the letter, or "yes" to the recommendation. Full options, evidence and the Leaf each
item came from are in `leaves/decisions.yml` under the same ID. Nothing has been decided for you.
Where code already follows a recommendation, rejecting it means a code change, and the YAML lists
that change under `if_rejected`.

**There are now two queues, not one.** Play and the App Store have independent calendars
(`MULTIPLATFORM.md`: never hold an Android fix for App Store review). **Part A blocks the Play
release** — that is the one with a date on it. **Part B blocks the first App Store submission** and
holds up nothing on Android. If you only have time for one sitting, do Part A.

## What changed since the last brief

1. **Spine 0.2 withdrew R7.** iOS is in scope, C11 was added, and every decision now carries a
   `platform:` tag (`android` / `ios` / `both`) instead of being forked into a second file.
2. **D-037 ("iOS: amend R7") is closed as superseded, not decided.** The Spine bump removed its
   subject. Its two live halves survived as new entries: *what is iOS for* (D-040) and *what shape
   the launch takes* (D-041).
3. **Apple has no AI-content policy.** Compliance fetched the App Review Guidelines in full: "AI"
   appears in exactly one guideline, about sharing data with third-party AI. The per-reply Report
   sheet that is a *documented gap* on Play is a *clean pass* on Apple. Same code, two verdicts.
4. **Apple has no 12-tester / 14-day gate.** That inverts the old plan. iOS could reach the store
   *before* Android production, not after. It is now a choice (D-041), not a constraint.
5. **Six Leaves proposed new decisions at once, all numbering from D-038.** They have been merged and
   renumbered into one sequence, D-038 to D-059. The map from each Leaf's number to the final one is
   at the top of `decisions.yml`. Where three Leaves raised the same thing — the iOS privacy wording,
   the profile mechanism, the memory entitlement — it is now one entry naming all of them.
6. **Four choices you thought were Android-only are now two-store choices**: the account type, the
   age rating, the report mailbox and the privacy wording. They are in Part A, marked ★.

---

## Part A — blocks the Play release, in the order they must be made

**1. D-020 ★ — Developer account type, verified before 2026-09-30?** *Deadline: 14 days.*
Recommend: whichever account you can verify fastest. Start today.
- Personal: no D-U-N-S. Production opens at least 14 days after 12 testers opt in.
- Organisation: needs D-U-N-S, lead time unknown. The 12-tester exemption is **not verified**.
- Miss the date: testers and users in BR, ID, SG and TH cannot install on certified phones.
- **Now also the Apple call.** Apple enrolment is $99/yr with *no* tester gate; individual enrolment
  publishes your **legal name as the seller** on every product page, organisation needs a D-U-N-S and
  a public website on your own domain. Same trade-off, both stores — decide it once.

**2. D-010 ★ — Which monitored mailbox receives reports?** *Before the first upload.*
Recommend: one mailbox for reports, the public Play contact and the privacy contact.
- `tools/release_check.sh` fails today on the placeholder, and so does the iOS check.
- It is now **also** the iOS report address (an `Info.plist` key) and the App Store support contact.
  One address, three forms, or you will be answering mail in two places.

**3. D-021 — Per-reply Report, and amend SPINE §3 to "Send, Stop, Copy, Report"?** *Before the first upload.*
Recommend: (b) Report on every reply → in-app sheet → hand off to email. Already built and working.
- The Play "report without exiting the app" gap is unchanged and remains the review risk it was.
- **New:** on Apple the same sheet *passes* Guideline 1.2 outright, and the iOS mail composer opens
  inside the app, which is better evidence of intent than Android's. This half is settled by evidence
  and needs only your stamp.

**4. D-022 — Privacy policy: host and owner?** *Before the first upload and before the Console forms.*
Recommend: GitHub Pages, no analytics, in-app text kept. One named owner for the text.
- The hosted draft and the in-app text **still disagree on retention**. Fix before upload.
- You supply: developer name as shown on the store, repo URL, contact (D-010), retention (D-023).
- iOS needs the same URL plus a **support page** that reaches a human — a repo README does not count.

**5. D-023 ★ — How long are report emails kept?** *With D-022.*
Recommend: 12 months, worded identically in both copies, deletion on request. Same answer both stores.

**6. D-024 ★ — Age: 18+ on Play, and the Apple override?** *Before the Console App content forms.*
Recommend: 18+ on Play; on Apple answer the questionnaire honestly (it returns about 4+) and then use
Apple's documented manual override to 18+. **One position, two mechanisms.**
- If you say 18+ on Play and leave 4+ on Apple, that is a position you cannot defend to either store.
- The cost is real and GTM wants it on the record: 18+ hides the app from anyone with a Screen Time
  restriction below 18+ — common on shared family phones in exactly our markets — and maps higher
  again in some territories. Reversible once the red-team eval (D-026) exists.

**7. D-025 ★ — "No data collected"?** *Before the Console App content forms.*
Recommend: yes on Play; "Data Not Collected" on Apple. Apple's definition of "collect" is narrower, so
the same answer is easier to defend there. Report emails are described in the privacy policy.

**8. D-018 — App signing key: Google-generated (A) or your own via PEPK (B)?** *Provisional A at the
first Internal upload; final after W18; locked at the first Open or Production release.*
Recommend: A, if W18 shows Play's universal APK carries the model aligned and installs both ways.
- **Android only.** Apple's model is different and is a separate decision (D-046) — do not answer both
  from the same instinct.

**9. D-009 ★ — RAM floor for gate layers 2 and 3?** *Needs W02 phone numbers. Before any track wider
than Internal testing.*
Recommend: keep 3.3 GiB if W02 shows headroom; put the same value in the Console rule.
- **This number now sets the iOS floor too** (D-042). Only the enforcement differs.

**10. D-017 — Is 0.6B good enough, and what may the listing promise now?** *Interim answer before the
listing goes up; final after W04.*
Recommend (interim): drop "polite" from the listing and from the first empty-state example.
- The polite rewrite echoed the input unchanged 6 of 6 on device. The backup example flipped who was late.
- iOS raises the stakes: App Store review scrutinises on-device model output more closely, and Apple's
  age questionnaire asks how chatbot output affects the *frequency* of sensitive content.

---

## Part B — blocks the first App Store submission (nothing on Android waits for these)

**11. D-040 — What is iOS for, in one sentence in the Spine?** *No deadline; everything below inherits it.*
GTM's proposed sentence: *"iOS reaches the people who recommend Arivu, and is where the second device
profile is proven before an 8 GB Android phone inherits it."* This is a Spine edit, so only you make
it. Leaving it implicit means re-running the same argument inside D-041, D-059 and D-024.

**12. D-039 — The iOS privacy wording.** *Before any iOS listing copy exists.* **The headline claim.**
On Android "no internet" is proved by a missing permission. On iOS there is no permission to withhold.
Design, Compliance, GTM and iOS Engineering all say the Android sentence must **not** be reused.
Recommend: iOS-specific copy saying exactly what is checkable — no networking code, public source,
"Data Not Collected", and the Airplane Mode test the user can run herself. Until the binary check
exists, the copy may **not** say "our build check fails if any is added".

**13. D-042 — Minimum iOS version.** *Before the listing can be finished.*
It is the App Store's only pre-install filter; there is no device-exclusion catalogue. Recommend:
keep 17.0 for the first build, derive the shipping number from the same measurement as D-009.
Too low means charging someone a 400 MB download to reach a wall. Raising it later drops users.

**14. D-043 — What happens to a reply when the user backgrounds the app on iOS?**
iOS gives roughly 30 seconds; a full reply takes about 96. Recommend: stop and keep the partial reply,
exactly as process death already does on Android. The alternative — a shorter reply cap on iOS — is a
platform-shaped limit, which is what C11 forbids.

**15. D-046 — iOS signing and certificate custody.** *Before the first TestFlight upload.*
**No recommendation yet, deliberately.** Apple's model is not Play App Signing and the analogy misleads.
One day of research (W72) has to happen first. Flagging it now because it is a lead-time item.

**16. D-049 — M5's wording across two platforms.** *A Spine edit.*
Recommend: restate M5 as "no network capability in the shipped artifact, by the platform's strongest
mechanism", with two checkers named. The alternative is a second metric for iOS, which reads as though
the two platforms have different privacy goals.

**17. D-038 — Ratify profiles as the C11 mechanism.** *Blocks the first iOS build, not Play.*
Recommend: yes — the arithmetic stays in `/core`, the capability vocabulary stays closed to
`[chat, longform]`, and adding `tools` is a Spine amendment argued once for both platforms. The
tripwire to accept with it: the day a second profile is shippable, the candidate list moves out of
`/core`. Note what is still missing — **no shell calls the profile code yet**, so C11 currently has a
mechanism and no user.

**18. D-041 — Launch shape.** *Not a blocker, but it decides the calendar.*
Recommend: couple the **announcement**, not the release — submit iOS with "Manually release this
version" and release it the day Play goes live; if iOS is not approved, Android ships alone.

---

## The 40 non-blocking decisions still open

Twenty-four carry over unchanged and keep their recommendations (D-002 to D-008, D-011 to D-016,
D-019, D-026 to D-034, D-036). Sixteen are new this round; two of those, D-040 and D-041, are in
Part B above because they gate the iOS queue. The other fourteen all have a clear recommendation in
the YAML — "yes to the recommendations" closes them:

| ID | Question | Recommendation |
|---|---|---|
| D-044 | Local notifications on iOS? | No. It would be the first permission prompt in a product that asks for nothing |
| D-045 | Does the iOS gate screen have a button? | No button, plus one line saying how to remove the app |
| D-047 | Request the increased-memory-limit entitlement? | **No** — already removed from the entitlements file; stamp to confirm |
| D-048 | A headroom margin before a device is accepted? | Yes, keyed on how good the measurement is, not on the platform |
| D-050 | A 4B profile on iOS later? | Not due now; recorded so it is not discovered at submission |
| D-051 | Metal on iOS? | Off. GPU buffers are charged memory; it would delete the property the budget rests on |
| D-052 | One prompt builder or three? | One, in `/core`, once the parity tests run on hardware |
| D-053 | One copy catalogue owned by Design? | Yes — cheapest now, before the iOS strings are written |
| D-054 | Clipboard confirmation | Arivu confirms only where the OS does not |
| D-055 | "Phone", not "iPhone", in shared sentences | Yes |
| D-056 | One NOTICE or one per platform? | Generated per platform from one source; not urgent |
| D-057 | Do the two listings mention each other? | No |
| D-058 | Does a profile difference ever appear in store copy as a feature? | No — only as a ceiling |
| D-059 | iOS storefronts | All 175 from day one, if D-040 says iOS is for recommenders |

## Spine and BRIEF amendments waiting on you (not applied)

The five from the last brief still stand (SPINE §3 "Send, Stop, Copy, Report"; the permissions
allow-list; "enforcement begins"; the asset-pack size correction; the memory budget). Three are new:

6. **A sentence in the Spine saying what iOS is for** (D-040).
7. **M5 restated for two platforms** (D-049).
8. **C10's promise on iOS**: if D-043 goes to "stop and keep the partial", C10's sentence still holds,
   but the Spine should record that the mechanism differs and that the difference is forced by the OS.

## Loose ends (owners, not decisions)

- ~~`ios/App/Support/Arivu.entitlements` requests the increased-memory-limit entitlement.~~
  **Closed 2026-09-16:** the entitlement was removed, so the file now requests nothing and code
  agrees with both Leaves' advice. D-047 is still yours to stamp, and the file records the
  measurement that would bring the entitlement back.
- `ios/App/Resources/licenses/index.txt` ships rows for the Swift runtime and libc++, which
  `licence-audit.md` §7.4 says are deliberately absent on iOS. One of the two is wrong (D-056).
- `ios/project.yml` already fixes the deployment target at 17.0, before the measurement that is
  supposed to derive it exists (D-042).
- `play-policy-checklist.md` §1 and §1b still cite the old "D-018"/"D-019" for Report and safeguards;
  they are D-021 and D-026.
- `store-listing.md` still says "report it from the About screen" and "Send / Stop / Copy".
- The 14-day closed test **is** on Android's critical path; `ios-port.md` treats it as free budget for
  the iOS port, which Compliance's finding has now undercut.

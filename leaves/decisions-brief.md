---
spine_version: 0.1
leaf: decisions/brief
source: leaves/decisions.yml (34 entries, all pending, all human-adjudicated)
prepared: 2026-09-15
---

# Decisions brief for Hari: one sitting

11 decisions block release. They are listed in the order they must be made. Answer each with the letter,
or "yes" to the recommendation. Evidence and full options are in `leaves/decisions.yml` under the same ID.
Nothing here has been decided for you. Where code already follows a recommendation, rejecting it means a
code change, and the YAML lists that change under `if_rejected`.

## Blocking, in order

**1. D-020: Developer account type, verified before 2026-09-30?** *Deadline 2026-09-30 (15 days).*
Recommend: the account you can verify fastest. Start today. Plan the 12-tester, 14-day closed test either way.
- Personal: no D-U-N-S. Production opens at least 14 days after 12 testers opt in.
- Organisation: needs D-U-N-S, lead time unknown. Exemption from the 12-tester test is **not verified**.
- Miss the date: testers and users in BR, ID, SG and TH cannot install on certified phones.

**2. D-001: Package name?** *Before the first upload. Irreversible.*
Recommend: `io.github.brettleehari.arivu` if you control arivu.org, otherwise the reverse of a domain you own.
- Once uploaded it is permanent. Iteration-2's APK and developer-verification registration are tied to it.

**3. D-010: Report mailbox?** *Before the first upload. `release_check.sh` fails until it is set.*
Recommend: one monitored mailbox for reports, the public Play contact and the privacy contact.
- With per-reply reports (D-021), reports contain reply text, so this mailbox holds user text (see D-023).

**4. D-021: Per-reply Report, and amend SPINE §3 to "Send, Stop, Copy, Report"?** *Before the first upload.*
Recommend: (b) Report on every reply opens an in-app sheet, then hands off to email. Already built and working on the emulator.
- (a) Report by email from About only: the most likely to fail Play's "report without exiting the app" rule.
- (b) Report on each reply: best fit to the rule without a network. A reviewer may still object to the email step (unverified).
- (c) (b) plus a report log screen: one more screen and no policy gain.

**5. D-022: Privacy policy host and owner?** *Before the first upload (the text ships in the app) and before the Data safety form.*
Recommend: GitHub Pages with no analytics, plus the in-app text. One owner for the text (proposed: Compliance). You supply your developer name and the repo URL.
- The hosted draft and the in-app text **already disagree** on retention. That has to be fixed before upload.
- arivu.org also works, but only if D-001 confirms you control that domain.

**6. D-023: How long are report emails kept?** *With D-022.*
Recommend: 12 months, stated the same way in both copies, with deletion on request.

**7. D-024: Target audience?** *Before the Console App content forms.*
Recommend: 18+ only, and "Appeals to children: No".
- Choosing under-13 brings the full Families policy and a much higher output-safety bar.

**8. D-025: Data safety answer?** *Before the Console App content forms.*
Recommend: "No data collected". The privacy policy describes the report emails users choose to send.
- Declaring "Messages collected" instead is the cautious reading, but it gives up the "No data collected" label.

**9. D-018: App signing key?** *Pick A provisionally at the first Internal upload. Confirm after W18. Locked at the first Open or Production release.*
Recommend: A, a Google-generated key, if W18 shows Play's universal APK contains the model aligned and installs over the Play copy in both directions.
- A: Google holds the key. The off-Play APK must be downloaded from Play.
- B: your own key via PEPK. If it leaks, attackers can ship trusted updates. If it is lost, off-Play updates end.

**10. D-009: RAM floor (gate layers 2 and 3)?** *Needs W02 phone numbers first. Set before any track wider than Internal.*
Recommend: keep 3.3 GiB if W02 shows headroom, and put the same value in the Console rule.
- Raising the floor excludes some "4 GB" phones and changes the store listing line.

**11. D-017: Is 0.6B good enough, and what should the listing promise now?** *Final answer after W04. Interim answer before the listing goes up.*
Evidence so far: the "polite" rewrite echoed the input unchanged in 6 of 6 emulator tries. The backup example swapped who was late.
Recommend (interim): remove "polite" from the listing and from the first empty-state example until W04 passes.
- Keep the wording: the listing makes a claim its own no-accuracy-claims rule would reject.
- After W04, the choices are to ship 0.6B, narrow the "good at" copy, or move to 1.7B (it now fits within Play's size limits, see D-004).

## Non-blocking

| ID | Question | Recommendation | Note |
|---|---|---|---|
| D-002 | Amend "Permissions: None" to the enforced allow-list | Yes | Stamp only; code and check already match |
| D-003 | onStop keeps a reply that is still being written | Yes | Emulator pass |
| D-004 | 1.7B fallback | Decide at W03 | Size is no longer the blocker (1.5 GB per pack, 4 GB total) |
| D-005 | Keep both ModelSource classes | Yes | |
| D-006 | ACTION_DELETE plus permission | Keep | Emulator API 36 pass; phone test in W10 |
| D-007 | Thinking mode off, fixed sampling | Keep | |
| D-008 | Thread heuristic | From W02 | |
| D-011 | "Clear conversation" action | Architecture: add before production | If yes, fold it into the D-021 §3 amendment |
| D-012 | Idle timer as main trigger + trim handlers | Keep | Emulator pass |
| D-013 | `.gguf.so` alignment trick | Keep; W18 mandatory | Emulator device split at offset 16384 |
| D-014 | UI language | English for Wave A | Decide translation before Wave B |
| D-015 | Weight repacking | Off; decide from W02 | |
| D-016 | compileSdk 37 | Yes | Settled by evidence |
| D-019 | Model provenance (Unsloth quantised it) | Document now; self-quantise in iteration-2 | NOTICE already updated |
| D-026 | Output safeguards | System prompt + red-team slice in W04 | Review risk; prompt barely changes refusals at 0.6B |
| D-027 | Code transparency | Adopt if W18 shows it takes under half a day | |
| D-028 | n_outputs_max = 1 | Yes | **Settled by evidence**: 309 → 27 MiB; needs only your stamp |
| D-029 | Country waves A then B | Yes | B is gated on D-014, D-017 and verification |
| D-030 | Tapping an example fills the input | Yes | Pick examples that W04 supports |
| D-031 | British spelling | Keep | |
| D-032 | "Send continue" at the reply limit | Keep; test in W04 | |
| D-033 | Truncate whole exchanges, not single turns | Yes; Engineering + Design | |
| D-034 | ~46 MB native heap after an idle free | Measure on the phone (W08) first | Emulator number only |

## Proposed Spine and CLAUDE.md amendments (for you to approve, not applied)

Approving any of these starts the propagation discipline: bump the version, add a changelog entry, run `tools/propagate.py`.

1. **SPINE §3 and CLAUDE.md "Scope of the single screen"**: "Send. Stop. Copy message." becomes "Send, Stop, Copy, Report" (D-021). Add "Clear conversation" here too if D-011 is yes.
2. **CLAUDE.md "Permissions"**: "None" becomes "No network or runtime-prompted permissions. Allowed: FOREGROUND_SERVICE, REQUEST_DELETE_PACKAGES, and the AndroidX DYNAMIC_RECEIVER_NOT_EXPORTED signature permission" (D-002).
3. **CLAUDE.md "Distribution"**: verification enforcement "began" becomes "begins" 2026-09-30 (D-002, D-020).
4. **CLAUDE.md "Build artifact"**: the 1 GB install-time limit becomes 1.5 GB per pack and 4 GB total. The "Fallback model" row is no longer ruled out by size (D-004).
5. **CLAUDE.md "Memory budget"**: compute buffers ~80 MB become ~28 MiB with n_outputs_max = 1. KV is 119 MiB and the weights map 373 MiB (D-028).

## Loose ends found while triaging (owners, not decisions)

- `play-policy-checklist.md` §1 and §1b still cite "D-018" and "D-019" for Report and safeguards. Those are now **D-021 and D-026** (Compliance).
- `store-listing.md` still says "report it from the About screen" and "Send / Stop / Copy". If D-021 is accepted, update both (GTM).
- `privacy-policy.html` and `strings.xml privacy_report_body` differ on retention (D-022, D-023).
- The 14-day closed test is not on Sequencing's critical path (Architecture B12).

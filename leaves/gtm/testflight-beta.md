---
spine_version: 0.2
leaf: gtm
artifact: TestFlight metadata for v0.1.0 (build 1) — text to paste into App Store Connect
scope: iOS only. Play's closed-test track has its own copy (store-listing.md)
---

# TestFlight — v0.1.0 (build 1)

Uploaded 2026-09-23. Everything below is text to paste; nothing here changes the app.

Apple's limits, verified against App Store Connect Help: **Beta App Description 4000**,
**What to Test 4000**, **Feedback Email** one address. Internal testing needs none of the review
fields; external testing needs all of them.

---

## Feedback email

```text
arivu.ai.org@gmail.com
```

The same address as the in-app Report and the privacy contact (D-010). One mailbox, three uses, so
a tester who replies and a tester who uses Report land in the same place.

---

## Beta App Description — 779 / 4000

```text
Arivu is a language model that runs on your phone. Not a link to one somewhere else — the whole
model is inside the app, which is why it works in aeroplane mode and why nothing you type leaves
the device. There is no account, no sign-in and no setup.

It is small enough to fit on a phone, so it is good at working with text you give it — rewriting,
shortening, explaining, summarising, translating, drafting — and unreliable about facts. It is
built to say so rather than to bluff.

It is also a way to see how such a thing works: every reply shows what it cost in tokens, you can
open any reply to read the exact text the model was given, and you can edit the instructions it
runs on and watch what changes.

The app is about 1 GB, because the model is in it. Install on Wi-Fi.
```

---

## What to Test — 1384 / 4000

```text
Thank you for trying this. It is a first build.

Please try, in roughly this order:

1. Send something it is FOR. Paste a message or a paragraph and ask it to rewrite, shorten or
   explain it. That is the work it is built for.

2. Ask it something it is bad at — a fact, a date, a score. It should tell you it may be wrong and
   suggest checking. If it states a fact confidently with no caveat, that is a bug and the most
   useful thing you can report.

3. Turn on aeroplane mode and keep going. Nothing should change. If anything does, tell me.

4. Tap "What Arivu read" between your question and its answer. That shows the exact text the model
   was given, including the instructions added to every message.

5. About > How Arivu works > Try it. Type a sentence and count its tokens with the real tokenizer.

6. Start a second conversation, switch between them, delete one.

Known and not worth reporting:
- The first launch is slow. It is loading a 1 GB model. Later launches are quicker.
- Replies are slower than a cloud assistant. It is a small model on a phone battery.
- It does not know about events, news or anything recent.

Worth reporting: wrong answers stated with confidence, anything that crashes, anything that loses
your text, and any moment you could not find a control you expected.

Use Report under any reply — it attaches that reply — or just email me back.
```

---

## Beta App Review Information — external testing only

Internal testing does not use these. They are written now so external submission is paste-only.

| Field | Value |
|---|---|
| Sign-in required | **No.** There is no account, no login and nothing to create |
| Demo account | Not applicable |
| Contact email | `arivu.ai.org@gmail.com` |
| Contact name / phone | Hari — fill in at submission |

### Notes for the reviewer — 633 chars

```text
Arivu runs a language model entirely on the device. The app links no networking framework and
requests no network permission, so it cannot make a request; this is verifiable with `otool -L` on
the binary. The privacy manifest declares no collected data and no tracking, and the three
required-reason API entries are file timestamps, disk space and UserDefaults, all within the app's
own container.

The app is about 1 GB because the model file is bundled. There is no download on first run and no
account.

Nothing in the app requires sign-in. To test it, type a sentence and press Send. Aeroplane mode
does not change its behaviour.
```

---

## Doing it from here instead of by hand

`tools/ios/testflight.py` drives all of this through the App Store Connect API, reading the copy
above rather than repeating it. It needs a key: App Store Connect → Users and Access →
Integrations → App Store Connect API → **+** (App Manager is enough), download
`AuthKey_<KEYID>.p8` **once** (Apple will not offer it again), put it in
`~/.appstoreconnect/private_keys/`, then:

```sh
export ASC_KEY_ID=<10-character key id>
export ASC_ISSUER_ID=<uuid above the key list>

tools/ios/testflight.py status                        # has the build finished processing?
tools/ios/testflight.py internal "Demo"               # group + build + what-to-test
tools/ios/testflight.py prepare "Hari S" "+44..."     # app fields external review requires
tools/ios/testflight.py external "Friends" a@x.com    # group + invite + submit for review
```

Internal testers still have to be users on the account — that is Apple's rule, not the tool's.
Add them under Users and Access; everything else above is automated.

## After processing finishes

1. TestFlight tab → the build appears as **0.1.0 (1)** once processing ends. A gigabyte takes
   longer than Apple's usual 15 minutes.
2. Answer **export compliance** if asked. The app declares `ITSAppUsesNonExemptEncryption=false`
   in Info.plist, so it should not ask.
3. Internal Testing → create a group → add the build → **add testers**. No review.
4. External testing, only if wanted: create a group, paste the fields above, submit for Beta App
   Review (about a day, not guaranteed).

**Tell testers to install on Wi-Fi.** It is a 1 GB download each.

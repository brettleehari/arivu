---
spine_version: 0.2
leaf: gtm
artifact: Reply to App Review, Guideline 2.1 Information Needed (submission f236539c, rejected 2026-10-01)
---

# Reply to App Review

Not a content or policy rejection. Guideline 2.1 "Information Needed — New App Submission" is the
questionnaire Apple sends accounts with limited review history. They asked for a screen recording
and six answers. Below is the text to paste into **Reply to App Review** and into **App Review
Information → Notes**, which is where they asked for it to live for future submissions.

---

## The reply

```text
Thank you for reviewing Arivu. Answers to all six points follow, and a screen recording captured on a physical iPhone is attached.

2. PURPOSE AND TARGET AUDIENCE

Arivu is an offline writing assistant. A language model runs entirely on the device; the app contains no networking code and makes no requests of any kind.

It is for two audiences. First, adults who want help working with text they already have — rewriting, shortening, explaining, summarising, translating, drafting — without that text leaving their phone. The problem it solves is that every comparable assistant requires an internet connection and sends the user's words to a server; Arivu does neither, and works in aeroplane mode. Second, people who want to understand how a language model actually works: the app shows what each reply cost in tokens, lets the user open any reply to read the exact text the model was given, and lets them edit the instructions the model runs on and see the behaviour change.

The app is deliberately honest about its limits. It is a small model, so it is good with the user's own text and unreliable about facts, and both the About screen and the "How Arivu works" page say so plainly.

3. SETUP AND ACCESS

There is nothing to set up. No account, no registration, no login, no credentials, no sample files, no permissions requested, no configuration.

To use the main features:
- Launch the app. A welcome screen explains what it is; tap "Start using Arivu".
- Type or paste text and tap Send. The first reply takes a few seconds while the model loads from the app bundle; later replies are immediate.
- Under any reply, tap "What Arivu read" to see the exact text given to the model.
- Tap About, then "How Arivu works", for the model card, the memory limits, and a tokenizer you can type into.
- Back arrow from the chat shows the conversation list; swipe or use Edit to delete a conversation.

There are no paid features, no in-app purchases and no subscriptions.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS

None. This is the unusual part of this app and we want to be precise about it.

- No AI service. The model is Qwen3-1.7B (Q4_K_M quantization, Apache 2.0, Alibaba Cloud), bundled inside the app, running locally through llama.cpp (MIT). No inference API is called.
- No data providers, no authentication service, no payment processor, no analytics, no advertising, no crash reporting, no third-party SDK of any kind.
- No networking framework is linked into the binary at all. This is verifiable: `otool -L` on the executable shows no CFNetwork, no Network.framework and no SystemConfiguration.

The only action that leaves the app is the Report button under a reply. It opens the user's own mail composer, pre-filled with the reply text and addressed to arivu.ai.org@gmail.com. Arivu sends nothing itself; the user reads the message and presses send, or does not.

5. REGIONAL DIFFERENCES

None. The app behaves identically in every region. There is no geo-gating, no region-specific content, no remote configuration and no server that could vary by territory — the entire app is the binary that was downloaded.

The model replies in whatever language the user writes in. That is a property of the model, not a regional variant, and it is the same model everywhere.

6. REGULATED INDUSTRY AND THIRD-PARTY MATERIAL

Arivu does not operate in a regulated industry. It is not a medical, financial, legal or educational-credential app, and makes no claims in those areas.

It does contain third-party material, and we hold the rights to redistribute all of it:
- Qwen3-1.7B model weights, Copyright 2024 Alibaba Cloud, Apache License 2.0, which expressly permits redistribution.
- llama.cpp, Copyright 2023-2026 The ggml authors, MIT License.

Both licences, in full, are shown inside the app under About > Licences, and in the NOTICE file of the public source repository at https://github.com/brettleehari/arivu. The app itself is open source under Apache 2.0, including the model weights, so every claim above can be checked against the source.

ON USER-GENERATED CONTENT

For completeness, since point 1 asks about it: Arivu has no user-generated content in the sense the guidelines describe. Nothing a user writes or receives is shared with anyone. There are no other users, no feed, no profiles, no messaging and no way to publish. Each person's conversation exists only in that app's private storage on that one device.

There is still a reporting mechanism: every reply has a Report button, which hands the exact reply to the user's mail app addressed to a monitored address. There is no blocking mechanism because there is nobody to block.
```

---

## The screen recording — what to film

Apple requires it **captured on a physical device running the latest OS**, starting from launch.
About ninety seconds. Record with Settings → Control Centre → Screen Recording, then the button in
Control Centre.

| # | Show | Why they asked |
|---|---|---|
| 1 | The home screen, then tap the Arivu icon | "must begin with launching the app" |
| 2 | The welcome screen, then "Start using Arivu" | the typical flow starts here |
| 3 | Type "Rewrite this politely: send me the report today" and Send. Let the reply finish | the core function, working |
| 4 | **Open Control Centre and turn on Aeroplane Mode**, then send a second message | this is the whole product, demonstrated rather than claimed |
| 5 | Tap "What Arivu read" under a reply, scroll the prompt | shows there is no hidden service |
| 6 | Tap **Report** under a reply; show the mail composer appearing; **cancel without sending** | the reporting mechanism they asked about |
| 7 | About → How Arivu works → scroll → "Try it", count tokens | the second half of the product |
| 8 | Back to the conversation list; swipe to delete one | data deletion, which they often ask about |

Do not show: anything not in the app, notifications, other apps.

Aeroplane mode in step 4 is the most valuable ten seconds in the recording. It answers point 4
better than any sentence can.

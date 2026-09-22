# The app icon

அ — the first letter of the Tamil alphabet and the first letter of அறிவு, *arivu*, which is what
the app is called and what it means. Brush-drawn, with a gold inline, kolam petals along the bowl
and a stepped gopuram motif at the stem. Tamil readers read a letter; everyone else reads a mark.

Supplied as finished artwork by Hari (2026-09-22), replacing a generated one. The generator,
`tools/ios/make_icon.swift`, was deleted with it: a script that would silently overwrite this art
on its next run is a trap, not a tool. Its reasoning is preserved in the commit that removed it —
the short version is that the icon before both of these was a speech bubble with a sparkle, which
is the icon every other LLM app already has.

## Two rules for anyone replacing these

**No alpha channel.** Apple rejects an App Store icon that carries one (ITMS-90717: "can't be
transparent nor contain an alpha channel"). Every file in the delivered pack had alpha, including
the 1024, and every file here has had it flattened away. Check with:

    sips -g hasAlpha 1024.png

**Check it at 40 points, not at 1024.** An icon lives on a home screen, in Settings and on a
notification. Fine detail that reads beautifully in a design tool disappears there. This artwork
was checked at 120, 87, 60 and 40 before it went in.

## Not here

No dark or tinted variants, so iOS 18+ derives the tinted appearance itself by desaturating. That
is fine and is what most apps ship. If bespoke variants are ever wanted, they need the source
artwork, which is not in this repository.

`leaves/gtm/assets/` holds the store marketing sizes for both listings.

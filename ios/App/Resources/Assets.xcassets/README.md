# Assets

Generated from `leaves/design/store-icon.svg` — the same path data as the Play icon and the Android
vectors (leaves/design.md §9: "change one, change all"). Regenerate after any geometry change:

    qlmanage -t -s 1024 -o <tmp> leaves/design/store-icon.svg
    # then flatten onto brand green; an App Store icon must have no alpha channel

| Asset | What | Status |
|---|---|---|
| `AppIcon.appiconset/arivu-1024.png` | one opaque 1024×1024 square, no alpha; the system applies the corner mask | rendered here, **not yet checked against the system mask** (Design's W74) |
| `LaunchMark.imageset` | the mark for `UILaunchScreen`, on brand green at 1×/2×/3× | rendered here, **not yet seen on a device** |
| `BrandGreen.colorset` | `#1F5C4A`, the same value in light and dark | authored |
| `LaunchBackground.colorset` | the launch screen's ground, same green | authored |

UNVERIFIED: no Xcode on the machine these were made on, so none of this has been through
`actool`. The renders are 1024/240/480/720 px PNGs with no alpha, which is what the catalogue asks
for, but the corner mask, the dark-mode launch screen and the Home Screen appearance are unseen.

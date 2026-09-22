// The app icon, generated rather than stored as an opaque PNG.
//
// WHY A SCRIPT. The old icon was a speech bubble with a sparkle in the corner, which is the icon
// every LLM app on both stores already has. Arivu's whole claim is that it is not one of those —
// it runs on your phone, with nothing behind it — and an icon that says "generic AI chat" spends
// the first impression arguing the opposite. It is also the one asset nobody can edit six months
// later if it arrives as a flattened file, so it arrives as the code that made it.
//
// WHAT IT IS. அ — the first letter of the Tamil alphabet, and the first letter of அறிவு, arivu,
// which is what the app is called and means knowledge. It is the app's own name in its own script:
// nothing else in either store looks like it, it needs no explanation to work as a mark, and it
// carries where this came from. Cream on the brand green, which is already the app's accent colour.
//
// Considered and rejected: a ring around the letter, which read as a seal and said "airgapped"
// rather well at 1024 and turned into a blob at 40 points; the letter in amber, which lost contrast
// against the green; and a cream slab with the letter knocked out, which is an icon inside an icon.
// The test that decided it was a contact sheet at 120, 87, 60 and 40 points, because that is where
// an icon actually lives.
//
// Usage: swift tools/ios/make_icon.swift [output directory]
//
// spine: C4 — everything that ships is something a fork can rebuild.

import AppKit
import CoreText
import Foundation

let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "ios/App/Resources/Assets.xcassets/AppIcon.appiconset"

func rgb(_ h: UInt32) -> CGColor {
    CGColor(red: CGFloat((h >> 16) & 0xff)/255, green: CGFloat((h >> 8) & 0xff)/255,
            blue: CGFloat(h & 0xff)/255, alpha: 1)
}

/// The glyph as an outline. Drawn as a path rather than as text so it can be measured, scaled and
/// centred exactly, and so the result does not depend on a text layout that may change.
func glyphPath(_ s: String, font: String) -> CGPath {
    let f = CTFontCreateWithName(font as CFString, 700, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f]))
    let path = CGMutablePath()
    for run in (CTLineGetGlyphRuns(line) as! [CTRun]) {
        let rf = unsafeBitCast(CFDictionaryGetValue(CTRunGetAttributes(run),
                    Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()), to: CTFont.self)
        let n = CTRunGetGlyphCount(run)
        var g = [CGGlyph](repeating: 0, count: n), p = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRangeMake(0, n), &g)
        CTRunGetPositions(run, CFRangeMake(0, n), &p)
        for i in 0..<n {
            guard let gp = CTFontCreatePathForGlyph(rf, g[i], nil) else { continue }
            let t = CGAffineTransform(translationX: p[i].x, y: p[i].y)
            path.addPath(gp, transform: t)
        }
    }
    return path
}

enum Appearance { case light, dark, tinted }

func icon(_ S: CGFloat, _ mode: Appearance) -> CGImage {
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    switch mode {
    case .light:
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [rgb(0x1F6450), rgb(0x0C352B)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
    case .dark:
        // Darker, because iOS draws this one against a dark home screen and the light version
        // glows against it.
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [rgb(0x11382E), rgb(0x05130F)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
    case .tinted:
        // Greyscale on an OPAQUE dark ground, not a transparent one. iOS maps luminance onto the
        // tint the user picked, so a transparent background gives it nothing to map and the icon
        // arrives as a blank tile — which is exactly what the first attempt produced.
        c.setFillColor(CGColor(gray: 0, alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: S, height: S))
    }

    let p = glyphPath("அ", font: "Tamil MN Bold")
    let b = p.boundingBox
    let scale = (S * 0.60) / max(b.width, b.height)
    // Nudged right: the glyph's visual mass sits left of its bounding-box centre because the tall
    // right stem is thin, so the mathematical centre reads as off-centre.
    var t = CGAffineTransform.identity
        .translatedBy(x: S/2 + S * 0.012, y: S/2)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -b.midX, y: -b.midY)
    c.addPath(p.copy(using: &t)!)
    c.setFillColor(mode == .tinted ? CGColor(gray: 1, alpha: 1) : rgb(0xF4F1E6))
    c.fillPath()
    return c.makeImage()!
}

func save(_ img: CGImage, _ path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                            "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("  \(path)")
}

try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, mode) in [("arivu-1024", Appearance.light),
                     ("arivu-1024-dark", .dark),
                     ("arivu-1024-tinted", .tinted)] {
    save(icon(1024, mode), "\(out)/\(name).png")
}

// iOS 18 draws three appearances from one entry each. Written here so the catalogue and the images
// cannot disagree about which files exist.
let contents = """
{
  "images" : [
    { "filename" : "arivu-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "arivu-1024-dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "arivu-1024-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "arivu", "version" : 1 }
}
"""
try! contents.write(toFile: "\(out)/Contents.json", atomically: true, encoding: .utf8)
print("  \(out)/Contents.json")

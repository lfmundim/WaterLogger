#!/usr/bin/env swift
// Generates WaterLogger app icons from the official Claude Design spec.
// SVG source: AppIcon.html — 256×256 viewBox, rendered at 1024×1024 (4× scale).
import AppKit
import CoreGraphics

// MARK: - Utilities

func makeContext(size: Int) -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    )!
}

func savePNG(_ ctx: CGContext, to path: String) {
    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("✓ \(path)")
}

func hex(_ h: String, a: Double = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: h.trimmingCharacters(in: .init(charactersIn: "#"))).scanHexInt64(&v)
    return CGColor(red:   CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8)  & 0xFF) / 255,
                   blue:  CGFloat( v        & 0xFF) / 255,
                   alpha: CGFloat(a))
}

// MARK: - Drop path (SVG M128 38 C… scaled by `s`)
// Original viewBox: 256×256.  Pass scale = iconSize / 256.

func dropPath(scale s: CGFloat) -> CGPath {
    // M128 38 C128 38 60 108 60 154 A68 68 0 0 0 196 154 C196 108 128 38 128 38 Z
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 128*s, y: 38*s))
    path.addCurve(to: CGPoint(x: 60*s, y: 154*s),
                  control1: CGPoint(x: 128*s, y: 38*s),
                  control2: CGPoint(x: 60*s,  y: 108*s))
    // Arc: center derived from A68 68 0 0 0 196 154  (large-arc=0, sweep=0→CCW in SVG/CG-flipped)
    // Circle centre between (60,154) and (196,154) with r=68: midpoint=(128,154), dy=0, so centre=(128,154)
    // CG uses bottom-left origin; we flip y at end, so just use the SVG coords directly in flipped ctx
    path.addArc(center: CGPoint(x: 128*s, y: 154*s),
                radius: 68*s,
                startAngle: .pi,       // angle from centre to (60,154)
                endAngle: 0,           // angle from centre to (196,154)
                clockwise: true)       // SVG sweep-flag=0 → CCW in SVG = CW in CG (y-flipped)
    path.addCurve(to: CGPoint(x: 128*s, y: 38*s),
                  control1: CGPoint(x: 196*s, y: 108*s),
                  control2: CGPoint(x: 128*s, y: 38*s))
    path.closeSubpath()
    return path
}

// MARK: - Main render

func drawIcon(size: Int, tinted: Bool = false) -> CGContext {
    let ctx  = makeContext(size: size)
    let sz   = CGFloat(size)
    let s    = sz / 256  // scale factor

    // CG is bottom-left; flip to match SVG top-left origin
    ctx.translateBy(x: 0, y: sz)
    ctx.scaleBy(x: 1, y: -1)

    let bounds = CGRect(x: 0, y: 0, width: sz, height: sz)

    // ── Squircle clip ─────────────────────────────────────────────────
    let r = sz * 0.2237   // iOS squircle approximation
    ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.clip()

    if tinted {
        // Tinted variant: solid black bg, white drop (iOS applies its tint)
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(bounds)

        ctx.addPath(dropPath(scale: s))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillPath()
        return ctx
    }

    // ── Background gradient ────────────────────────────────────────────
    // linearGradient id="bg" x1="0.2" y1="0" x2="0.8" y2="1"
    // stops: 0% #0f2060, 55% #081540, 100% #040c22
    do {
        let colors = [hex("0f2060"), hex("081540"), hex("040c22")] as CFArray
        let locs: [CGFloat] = [0, 0.55, 1]
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: locs)!
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: 0.2 * sz, y: 0),
            end:   CGPoint(x: 0.8 * sz, y: sz),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    // ── Ambient glow (radial) ──────────────────────────────────────────
    // radialGradient cx="50%" cy="42%" r="44%"  → color #3b9eff opacity 0.22 → 0
    do {
        let colors = [hex("3b9eff", a: 0.22), hex("3b9eff", a: 0)] as CFArray
        let locs: [CGFloat] = [0, 1]
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: locs)!
        let cx = 0.5  * sz
        let cy = 0.42 * sz
        let rad = 0.44 * sz
        ctx.drawRadialGradient(grad,
            startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
            endCenter:   CGPoint(x: cx, y: cy), endRadius: rad,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    // ── Water drop shadow (soft outer glow) ───────────────────────────
    // filter: feDropShadow dx=0 dy=8 stdDeviation=14 flood=#1a60e8 opacity=0.45
    // Approximated: draw a blurred, tinted version of the drop first
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 8*s),
                  blur: 28*s,
                  color: hex("1a60e8", a: 0.45))
    ctx.addPath(dropPath(scale: s))
    ctx.setFillColor(hex("1a60e8", a: 0.01))  // near-transparent so only shadow renders
    ctx.fillPath()
    ctx.restoreGState()

    // ── Drop inner glow (feGaussianBlur stdDeviation=5 → blurred copy) ─
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18*s, color: hex("52b5ff", a: 0.35))
    ctx.addPath(dropPath(scale: s))
    ctx.setFillColor(hex("52b5ff", a: 0.01))
    ctx.fillPath()
    ctx.restoreGState()

    // ── Drop fill gradient ─────────────────────────────────────────────
    // linearGradient id="dg" x1=128 y1=38 x2=128 y2=218 (userSpaceOnUse, scaled)
    // stops: 0% #b8e0ff, 38% #52b5ff, 78% #1f78f0, 100% #1044c8
    do {
        let colors = [hex("b8e0ff"), hex("52b5ff"), hex("1f78f0"), hex("1044c8")] as CFArray
        let locs: [CGFloat] = [0, 0.38, 0.78, 1]
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: locs)!
        ctx.saveGState()
        ctx.addPath(dropPath(scale: s))
        ctx.clip()
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: 128*s, y: 38*s),
            end:   CGPoint(x: 128*s, y: 218*s),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // ── Glass reflection arc ───────────────────────────────────────────
    // SVG: M100 120 C88 138 84 152 86 166 A44 44 0 0 0 108 200
    // Arc A44 44 0 0 0 108 200 from (86,166):
    //   center ≈ (129.8, 161.8), span 54.8° CCW (sweep=0).
    //   Converted to cubic bezier: k=0.324, offset=14.25
    //   CP1 = start + 14.25*(sin174.5°, 0.9954) = (87.4, 180.2)
    //   CP2 = end   - 14.25*(sin119.7°, 0.494)  = (95.6, 193.0)
    do {
        let arc = CGMutablePath()
        arc.move(to: CGPoint(x: 100*s, y: 120*s))
        arc.addCurve(to: CGPoint(x: 86*s,  y: 166*s),
                     control1: CGPoint(x: 88*s, y: 138*s),
                     control2: CGPoint(x: 84*s, y: 152*s))
        arc.addCurve(to: CGPoint(x: 108*s, y: 200*s),
                     control1: CGPoint(x: 87.4*s, y: 180.2*s),
                     control2: CGPoint(x: 95.6*s, y: 193.0*s))

        ctx.addPath(arc)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
        ctx.setLineWidth(8*s)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    // ── Specular glint (rotated ellipse) ──────────────────────────────
    // ellipse cx=104 cy=96 rx=14 ry=22 fill=rgba(255,255,255,0.14) rotate(-22,104,96)
    do {
        ctx.saveGState()
        ctx.translateBy(x: 104*s, y: 96*s)
        ctx.rotate(by: -22 * .pi / 180)
        let ellipsePath = CGPath(ellipseIn: CGRect(x: -14*s, y: -22*s, width: 28*s, height: 44*s), transform: nil)
        ctx.addPath(ellipsePath)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // ── Top-half shine ─────────────────────────────────────────────────
    // rect width=256 height=128 fill gradient white 0.10→0
    do {
        let colors = [CGColor(red:1,green:1,blue:1,alpha:0.10),
                      CGColor(red:1,green:1,blue:1,alpha:0)] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: [0,1])!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: sz, height: 128*s))
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: 0, y: 0),
            end:   CGPoint(x: 0, y: 128*s),
            options: [])
        ctx.restoreGState()
    }

    return ctx
}

// MARK: - Entry point

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let size = 1024
savePNG(drawIcon(size: size),             to: "\(outDir)/AppIcon-light.png")
savePNG(drawIcon(size: size),             to: "\(outDir)/AppIcon-dark.png")   // same art, dark variant
savePNG(drawIcon(size: size, tinted: true), to: "\(outDir)/AppIcon-tinted.png")
print("Done.")

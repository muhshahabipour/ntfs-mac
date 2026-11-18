import AppKit
import CoreGraphics

// Draws the app icon: a blue squircle with a white external drive and a "write" arrow.
let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
func grad(_ a: CGColor, _ b: CGColor) -> CGGradient { CGGradient(colorsSpace: cs, colors: [a, b] as CFArray, locations: [0, 1])! }

// Squircle with soft shadow (Apple icon grid: 824 pt body inside 1024).
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 190, cornerHeight: 190, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: c(0, 0, 0, 0.30))
ctx.addPath(squircle); ctx.setFillColor(c(0.04, 0.4, 1)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
ctx.drawLinearGradient(grad(c(0.30, 0.66, 1.0), c(0.03, 0.32, 0.95)), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// soft top highlight
ctx.drawRadialGradient(grad(c(1, 1, 1, 0.28), c(1, 1, 1, 0)), startCenter: CGPoint(x: 512, y: 960), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 960), endRadius: 620, options: [])

ctx.translateBy(x: 0, y: -40)
// Drive body.
let drive = CGRect(x: 232, y: 270, width: 560, height: 300)
let drivePath = CGPath(roundedRect: drive, cornerWidth: 70, cornerHeight: 70, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 24, color: c(0, 0.1, 0.4, 0.35))
ctx.addPath(drivePath); ctx.setFillColor(c(1, 1, 1)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(drivePath); ctx.clip()
ctx.drawLinearGradient(grad(c(1, 1, 1), c(0.86, 0.92, 1.0)), start: CGPoint(x: 512, y: 570), end: CGPoint(x: 512, y: 270), options: [])
ctx.restoreGState()

// Slot and activity LED.
let slot = CGPath(roundedRect: CGRect(x: 292, y: 330, width: 250, height: 26), cornerWidth: 13, cornerHeight: 26 / 2, transform: nil)
ctx.addPath(slot); ctx.setFillColor(c(0.04, 0.32, 0.9, 0.28)); ctx.fillPath()
ctx.setFillColor(c(0.19, 0.82, 0.35))
ctx.fillEllipse(in: CGRect(x: 672, y: 327, width: 32, height: 32))

// Write arrow dropping into the drive.
let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: 462, y: 860)); arrow.addLine(to: CGPoint(x: 562, y: 860))
arrow.addLine(to: CGPoint(x: 562, y: 770)); arrow.addLine(to: CGPoint(x: 632, y: 770))
arrow.addLine(to: CGPoint(x: 512, y: 640)); arrow.addLine(to: CGPoint(x: 392, y: 770))
arrow.addLine(to: CGPoint(x: 462, y: 770)); arrow.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: c(0, 0.1, 0.4, 0.3))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(c(1, 1, 1)); ctx.setStrokeColor(c(1, 1, 1))
ctx.setLineWidth(28); ctx.setLineJoin(.round); ctx.setLineCap(.round)
ctx.addPath(arrow); ctx.drawPath(using: .fillStroke)
ctx.endTransparencyLayer()
ctx.restoreGState()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

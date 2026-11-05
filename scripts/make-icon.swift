// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let outputDir = URL(fileURLWithPath: "Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Background squircle (macOS icon grid: 824pt body inside 1024pt canvas).
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let background = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.93, green: 0.27, blue: 0.24, alpha: 1),
        NSColor(calibratedRed: 0.78, green: 0.13, blue: 0.20, alpha: 1),
    ])!.draw(in: background, angle: -90)

    // Paper sheet with a folded corner.
    let paper = NSRect(x: 290 * s, y: 215 * s, width: 444 * s, height: 594 * s)
    let fold: CGFloat = 120 * s
    let sheet = NSBezierPath()
    sheet.move(to: NSPoint(x: paper.minX, y: paper.minY))
    sheet.line(to: NSPoint(x: paper.maxX, y: paper.minY))
    sheet.line(to: NSPoint(x: paper.maxX, y: paper.maxY - fold))
    sheet.line(to: NSPoint(x: paper.maxX - fold, y: paper.maxY))
    sheet.line(to: NSPoint(x: paper.minX, y: paper.maxY))
    sheet.close()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    sheet.fill()
    NSGraphicsContext.restoreGraphicsState()

    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: paper.maxX - fold, y: paper.maxY))
    corner.line(to: NSPoint(x: paper.maxX - fold, y: paper.maxY - fold))
    corner.line(to: NSPoint(x: paper.maxX, y: paper.maxY - fold))
    corner.close()
    NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
    corner.fill()

    // Markdown mark: "M↓".
    let markColor = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 1)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 190 * s, weight: .heavy),
        .foregroundColor: markColor,
    ]
    let mark = NSAttributedString(string: "M↓", attributes: attributes)
    let markSize = mark.size()
    mark.draw(at: NSPoint(x: paper.midX - markSize.width / 2, y: 470 * s))

    // "PDF" label band.
    let band = NSRect(x: paper.minX + 50 * s, y: 285 * s, width: paper.width - 100 * s, height: 120 * s)
    NSColor(calibratedRed: 0.85, green: 0.18, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(roundedRect: band, xRadius: 26 * s, yRadius: 26 * s).fill()
    let pdf = NSAttributedString(string: "PDF", attributes: [
        .font: NSFont.systemFont(ofSize: 92 * s, weight: .bold),
        .foregroundColor: NSColor.white,
        .kern: 6 * s,
    ])
    let pdfSize = pdf.size()
    pdf.draw(at: NSPoint(x: band.midX - pdfSize.width / 2, y: band.midY - pdfSize.height / 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let rep = drawIcon(size: CGFloat(base * scale))
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputDir.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
try? drawIcon(size: 512).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "docs/icon.png"))
print(process.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")

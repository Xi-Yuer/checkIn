import AppKit
import Foundation

private struct Palette {
    let background: NSColor
    let backgroundSecondary: NSColor
    let helmet: NSColor
    let visor: NSColor
    let ink: NSColor
    let violet: NSColor
    let yellow: NSColor
    let coral: NSColor
    let sky: NSColor
}

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

private func ellipse(_ rect: NSRect, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 0) {
    let path = NSBezierPath(ovalIn: rect)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

private func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
}

private func star(center: NSPoint, radius: CGFloat, fill: NSColor) {
    let path = NSBezierPath()
    for index in 0..<10 {
        let angle = CGFloat(index) * .pi / 5 - .pi / 2
        let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.43
        let point = NSPoint(
            x: center.x + cos(angle) * pointRadius,
            y: center.y + sin(angle) * pointRadius
        )
        index == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    fill.setFill()
    path.fill()
}

private func drawMascot(in rect: NSRect, palette: Palette) {
    let scale = min(rect.width, rect.height) / 760
    let centerX = rect.midX
    let centerY = rect.midY

    ellipse(
        NSRect(x: centerX - 270 * scale, y: centerY - 300 * scale, width: 540 * scale, height: 130 * scale),
        fill: palette.sky.withAlphaComponent(0.26)
    )

    roundedRect(
        NSRect(x: centerX - 185 * scale, y: centerY - 285 * scale, width: 370 * scale, height: 310 * scale),
        radius: 112 * scale,
        fill: palette.helmet
    )
    roundedRect(
        NSRect(x: centerX - 148 * scale, y: centerY - 250 * scale, width: 296 * scale, height: 235 * scale),
        radius: 84 * scale,
        fill: palette.violet
    )

    ellipse(
        NSRect(x: centerX - 292 * scale, y: centerY - 55 * scale, width: 584 * scale, height: 584 * scale),
        fill: palette.helmet,
        stroke: palette.yellow,
        lineWidth: 24 * scale
    )
    ellipse(
        NSRect(x: centerX - 238 * scale, y: centerY - 5 * scale, width: 476 * scale, height: 452 * scale),
        fill: palette.visor,
        stroke: palette.violet.withAlphaComponent(0.55),
        lineWidth: 15 * scale
    )

    let hair = NSBezierPath()
    hair.move(to: NSPoint(x: centerX - 190 * scale, y: centerY + 220 * scale))
    hair.curve(
        to: NSPoint(x: centerX + 188 * scale, y: centerY + 210 * scale),
        controlPoint1: NSPoint(x: centerX - 95 * scale, y: centerY + 385 * scale),
        controlPoint2: NSPoint(x: centerX + 125 * scale, y: centerY + 370 * scale)
    )
    hair.curve(
        to: NSPoint(x: centerX - 190 * scale, y: centerY + 220 * scale),
        controlPoint1: NSPoint(x: centerX + 95 * scale, y: centerY + 150 * scale),
        controlPoint2: NSPoint(x: centerX - 80 * scale, y: centerY + 145 * scale)
    )
    palette.ink.setFill()
    hair.fill()

    ellipse(NSRect(x: centerX - 122 * scale, y: centerY + 104 * scale, width: 46 * scale, height: 62 * scale), fill: palette.ink)
    ellipse(NSRect(x: centerX + 76 * scale, y: centerY + 104 * scale, width: 46 * scale, height: 62 * scale), fill: palette.ink)
    ellipse(NSRect(x: centerX - 172 * scale, y: centerY + 62 * scale, width: 66 * scale, height: 30 * scale), fill: palette.coral.withAlphaComponent(0.55))
    ellipse(NSRect(x: centerX + 106 * scale, y: centerY + 62 * scale, width: 66 * scale, height: 30 * scale), fill: palette.coral.withAlphaComponent(0.55))

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: centerX - 34 * scale, y: centerY + 54 * scale))
    smile.curve(
        to: NSPoint(x: centerX + 34 * scale, y: centerY + 54 * scale),
        controlPoint1: NSPoint(x: centerX - 16 * scale, y: centerY + 18 * scale),
        controlPoint2: NSPoint(x: centerX + 16 * scale, y: centerY + 18 * scale)
    )
    palette.ink.setStroke()
    smile.lineWidth = 12 * scale
    smile.lineCapStyle = .round
    smile.stroke()

    ellipse(NSRect(x: centerX - 222 * scale, y: centerY - 205 * scale, width: 76 * scale, height: 76 * scale), fill: palette.yellow)
    ellipse(NSRect(x: centerX + 146 * scale, y: centerY - 205 * scale, width: 76 * scale, height: 76 * scale), fill: palette.yellow)
    star(center: NSPoint(x: centerX, y: centerY - 145 * scale), radius: 58 * scale, fill: palette.yellow)

    star(center: NSPoint(x: centerX + 292 * scale, y: centerY + 286 * scale), radius: 55 * scale, fill: palette.yellow)
    star(center: NSPoint(x: centerX - 304 * scale, y: centerY + 230 * scale), radius: 30 * scale, fill: palette.sky)
    star(center: NSPoint(x: centerX + 285 * scale, y: centerY - 210 * scale), radius: 25 * scale, fill: palette.coral)
}

private func makePNG(size: Int, opaque: Bool, palette: Palette) -> Data {
    let dimension = CGFloat(size)
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: opaque ? 3 : 4,
        hasAlpha: !opaque,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    representation.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    if opaque {
        palette.background.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        ellipse(
            NSRect(x: -size / 3, y: size * 2 / 3, width: size, height: size),
            fill: palette.backgroundSecondary.withAlphaComponent(0.34)
        )
        ellipse(
            NSRect(x: size * 2 / 3, y: -size / 3, width: size, height: size),
            fill: palette.sky.withAlphaComponent(0.18)
        )
    } else {
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    }
    drawMascot(
        in: NSRect(x: dimension * 0.12, y: dimension * 0.10, width: dimension * 0.76, height: dimension * 0.76),
        palette: palette
    )
    NSGraphicsContext.restoreGraphicsState()
    return representation.representation(using: .png, properties: [:])!
}

private let regular = Palette(
    background: color(0x4A2A93),
    backgroundSecondary: color(0x8B6DE4),
    helmet: color(0xFFF8ED),
    visor: color(0xF4E9FF),
    ink: color(0x382343),
    violet: color(0x7C3AED),
    yellow: color(0xFDE68A),
    coral: color(0xFB7185),
    sky: color(0x7DD3FC)
)
private let dark = Palette(
    background: color(0x160D35),
    backgroundSecondary: color(0x4C2B8A),
    helmet: color(0xF9F3FF),
    visor: color(0xDCCBFF),
    ink: color(0x2C1838),
    violet: color(0x8B5CF6),
    yellow: color(0xFDE68A),
    coral: color(0xFB7185),
    sky: color(0x7DD3FC)
)
private let tinted = Palette(
    background: color(0x5B3AA9),
    backgroundSecondary: color(0x8B72D8),
    helmet: color(0xFDF9FF),
    visor: color(0xE8DFFF),
    ink: color(0x3C2765),
    violet: color(0x7250BA),
    yellow: color(0xEDE4FF),
    coral: color(0xC9B7F0),
    sky: color(0xD9CCF5)
)

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDirectory = root.appendingPathComponent("checkIn/Assets.xcassets/AppIcon.appiconset")
let launchDirectory = root.appendingPathComponent("checkIn/Assets.xcassets/LaunchLogo.imageset")
try FileManager.default.createDirectory(at: launchDirectory, withIntermediateDirectories: true)
try makePNG(size: 1024, opaque: true, palette: regular).write(to: iconDirectory.appendingPathComponent("AppIcon.png"))
try makePNG(size: 1024, opaque: true, palette: dark).write(to: iconDirectory.appendingPathComponent("AppIcon-dark.png"))
try makePNG(size: 1024, opaque: true, palette: tinted).write(to: iconDirectory.appendingPathComponent("AppIcon-tinted.png"))
try makePNG(size: 512, opaque: false, palette: regular).write(to: launchDirectory.appendingPathComponent("LaunchLogo.png"))

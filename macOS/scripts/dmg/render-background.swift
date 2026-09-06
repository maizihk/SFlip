import AppKit

// Draw at 2x, retaining a 720 x 528 point canvas for Retina Finder windows.
let size = NSSize(width: 720, height: 528)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440, pixelsHigh: 1056,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: size.height - y - h, width: w, height: h)
}
func text(_ value: String, y: CGFloat, height: CGFloat, font: NSFont, ink: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (value as NSString).draw(in: rect(24, y, 672, height), withAttributes: [
        .font: font, .foregroundColor: ink, .paragraphStyle: paragraph
    ])
}
NSGradient(starting: color(0.97, 0.98, 1), ending: color(0.91, 0.94, 0.98))!
    .draw(in: NSRect(origin: .zero, size: size), angle: -70)
text("DisplaySwitch", y: 40, height: 44, font: .systemFont(ofSize: 32, weight: .semibold),
     ink: color(0.13, 0.19, 0.28))
text("拖入应用程序，即可完成安装", y: 92, height: 28, font: .systemFont(ofSize: 16),
     ink: color(0.38, 0.44, 0.53))
for x: CGFloat in [84, 428] {
    NSColor.white.withAlphaComponent(0.72).setFill()
    let card = NSBezierPath(roundedRect: rect(x, 158, 208, 176), xRadius: 24, yRadius: 24)
    card.fill()
    NSColor.white.setStroke()
    card.lineWidth = 1
    card.stroke()
}
color(0.28, 0.48, 0.83).setStroke()
let arrow = NSBezierPath()
let arrowY = size.height - 236
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 331, y: arrowY))
arrow.line(to: NSPoint(x: 389, y: arrowY))
arrow.move(to: NSPoint(x: 378, y: arrowY + 11))
arrow.line(to: NSPoint(x: 389, y: arrowY))
arrow.line(to: NSPoint(x: 378, y: arrowY - 11))
arrow.stroke()
text("安装后推出此磁盘映像，从“应用程序”打开", y: 364, height: 24,
     font: .systemFont(ofSize: 13), ink: color(0.38, 0.44, 0.53))
text("替换旧版前，请先退出 DisplaySwitch", y: 393, height: 20,
     font: .systemFont(ofSize: 11), ink: color(0.48, 0.54, 0.62))
NSGraphicsContext.restoreGraphicsState()
try bitmap.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

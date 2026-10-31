import AppKit
import CoreGraphics

func createIcon() {
    let size = CGSize(width: 1024, height: 1024)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap rep")
        return
    }
    
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    
    // 1. Drop Shadow under Squircle
    cg.saveGState()
    let shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
    cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: shadowColor)
    
    // 2. Base Squircle (macOS Standard: 824x824 centered in 1024x1024, cornerRadius: 185)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    
    cg.addPath(squirclePath)
    cg.setFillColor(NSColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 1.0).cgColor)
    cg.fillPath()
    cg.restoreGState()
    
    // 3. Inside Squircle Gradient
    cg.saveGState()
    cg.addPath(squirclePath)
    cg.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let baseGradientColors = [
        NSColor(red: 0.14, green: 0.16, blue: 0.24, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
    ] as CFArray
    let baseGradient = CGGradient(colorsSpace: colorSpace, colors: baseGradientColors, locations: [0.0, 0.45, 1.0])!
    cg.drawLinearGradient(baseGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    
    // 4. Subtle Circuit Grid Pattern
    cg.setStrokeColor(NSColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 0.08).cgColor)
    cg.setLineWidth(2)
    for x in stride(from: 140, to: 884, by: 40) {
        cg.move(to: CGPoint(x: x, y: 120))
        cg.addLine(to: CGPoint(x: x, y: 904))
    }
    for y in stride(from: 140, to: 884, by: 40) {
        cg.move(to: CGPoint(x: 120, y: y))
        cg.addLine(to: CGPoint(x: 904, y: y))
    }
    cg.strokePath()
    
    // 5. Silicon Chip Package (Center, 540x540)
    let chipRect = CGRect(x: 242, y: 242, width: 540, height: 540)
    let chipPath = CGPath(roundedRect: chipRect, cornerWidth: 54, cornerHeight: 54, transform: nil)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    cg.addPath(chipPath)
    cg.setFillColor(NSColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1.0).cgColor)
    cg.fillPath()
    cg.restoreGState()
    
    // Chip Inner Gradient & Border
    cg.saveGState()
    cg.addPath(chipPath)
    cg.clip()
    
    let chipGradColors = [
        NSColor(red: 0.16, green: 0.18, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0).cgColor
    ] as CFArray
    let chipGrad = CGGradient(colorsSpace: colorSpace, colors: chipGradColors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(chipGrad, start: CGPoint(x: 512, y: 782), end: CGPoint(x: 512, y: 242), options: [])
    
    // Chip Inner Circuit Bus
    cg.setStrokeColor(NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 0.25).cgColor)
    cg.setLineWidth(3)
    let innerFrame = chipRect.insetBy(dx: 40, dy: 40)
    let innerPath = CGPath(roundedRect: innerFrame, cornerWidth: 28, cornerHeight: 28, transform: nil)
    cg.addPath(innerPath)
    cg.strokePath()
    
    // Glowing Corner Bus Accents (Cyan, Purple, Green, Orange)
    let busThickness: CGFloat = 8
    
    // Top-Left: Cyan (CPU)
    cg.setStrokeColor(NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.85).cgColor)
    cg.setLineWidth(busThickness)
    cg.setLineCap(.round)
    cg.move(to: CGPoint(x: 270, y: 700))
    cg.addLine(to: CGPoint(x: 270, y: 750))
    cg.addLine(to: CGPoint(x: 320, y: 750))
    cg.strokePath()
    
    // Top-Right: Purple (GPU)
    cg.setStrokeColor(NSColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 0.85).cgColor)
    cg.move(to: CGPoint(x: 754, y: 700))
    cg.addLine(to: CGPoint(x: 754, y: 750))
    cg.addLine(to: CGPoint(x: 704, y: 750))
    cg.strokePath()
    
    // Bottom-Left: Green (RAM)
    cg.setStrokeColor(NSColor(red: 0.0, green: 0.9, blue: 0.4, alpha: 0.85).cgColor)
    cg.move(to: CGPoint(x: 270, y: 324))
    cg.addLine(to: CGPoint(x: 270, y: 274))
    cg.addLine(to: CGPoint(x: 320, y: 274))
    cg.strokePath()
    
    // Bottom-Right: Orange (SSD)
    cg.setStrokeColor(NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.85).cgColor)
    cg.move(to: CGPoint(x: 754, y: 324))
    cg.addLine(to: CGPoint(x: 754, y: 274))
    cg.addLine(to: CGPoint(x: 704, y: 274))
    cg.strokePath()
    
    // 6. Central Silicon Die (Inner core, 320x320)
    let dieRect = CGRect(x: 352, y: 352, width: 320, height: 320)
    let diePath = CGPath(roundedRect: dieRect, cornerWidth: 36, cornerHeight: 36, transform: nil)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.7).cgColor)
    cg.addPath(diePath)
    cg.setFillColor(NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor)
    cg.fillPath()
    cg.restoreGState()
    
    // Die Border Highlight
    cg.addPath(diePath)
    cg.setStrokeColor(NSColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 0.5).cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
    
    // 7. Typography "CGPU" in Die
    let title = "CGPU" as NSString
    let font = NSFont.systemFont(ofSize: 74, weight: .black)
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let titleSize = title.size(withAttributes: titleAttributes)
    let titlePoint = CGPoint(x: 512 - titleSize.width / 2, y: 520 - titleSize.height / 2)
    
    // Subtle Title Glow
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 16, color: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7).cgColor)
    title.draw(at: titlePoint, withAttributes: titleAttributes)
    cg.restoreGState()
    
    // Subtitle "MONITOR"
    let sub = "SYSTEM MONITOR" as NSString
    let subFont = NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9),
        .kern: 3.0
    ]
    let subSize = sub.size(withAttributes: subAttrs)
    sub.draw(at: CGPoint(x: 512 - subSize.width / 2, y: 440), withAttributes: subAttrs)
    
    // Telemetry Wave / Sparkline across Die
    cg.setStrokeColor(NSColor(red: 0.0, green: 0.9, blue: 0.5, alpha: 0.8).cgColor)
    cg.setLineWidth(3.5)
    cg.setLineJoin(.round)
    cg.move(to: CGPoint(x: 390, y: 400))
    cg.addLine(to: CGPoint(x: 430, y: 400))
    cg.addLine(to: CGPoint(x: 450, y: 418))
    cg.addLine(to: CGPoint(x: 470, y: 388))
    cg.addLine(to: CGPoint(x: 500, y: 424))
    cg.addLine(to: CGPoint(x: 525, y: 395))
    cg.addLine(to: CGPoint(x: 550, y: 410))
    cg.addLine(to: CGPoint(x: 580, y: 400))
    cg.addLine(to: CGPoint(x: 634, y: 400))
    cg.strokePath()
    
    cg.restoreGState() // End chip clip
    
    // Chip Outer Stroke
    cg.addPath(chipPath)
    cg.setStrokeColor(NSColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 0.5).cgColor)
    cg.setLineWidth(2.5)
    cg.strokePath()
    
    // 8. Outer Squircle Gloss Border
    cg.addPath(squirclePath)
    cg.setLineWidth(3)
    let borderGrad = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor.white.withAlphaComponent(0.45).cgColor,
        NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3).cgColor,
        NSColor.white.withAlphaComponent(0.08).cgColor
    ] as CFArray, locations: [0.0, 0.35, 1.0])!
    cg.saveGState()
    cg.replacePathWithStrokedPath()
    cg.clip()
    cg.drawLinearGradient(borderGrad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    cg.restoreGState()
    
    cg.restoreGState() // End squircle clip
    
    NSGraphicsContext.restoreGraphicsState()
    
    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: "AppIcon_1024.png"))
    print("Successfully created AppIcon_1024.png")
}

createIcon()

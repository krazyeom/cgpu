import AppKit
import CoreGraphics

func renderDMGBackground(width: CGFloat, height: CGFloat, scale: CGFloat) -> NSBitmapImageRep? {
    let pixelWidth = Int(width * scale)
    let pixelHeight = Int(height * scale)
    
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create rep for scale \(scale)")
        return nil
    }
    
    rep.size = NSSize(width: width, height: height)
    
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = context
    let cg = context.cgContext
    
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high
    
    // Scale context so all drawing coordinates are in logical points (0..width, 0..height)
    cg.scaleBy(x: scale, y: scale)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // 1. Dark Luxury Gradient Background
    let bgColors = [
        NSColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(bgGrad, start: CGPoint(x: width / 2, y: height), end: CGPoint(x: width / 2, y: 0), options: [])
    
    // 2. Subtle Glow Orbs behind drop target plates
    cg.saveGState()
    let cyanGlow = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.15).cgColor,
        NSColor.clear.cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    cg.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: 170, y: 230), startRadius: 0, endCenter: CGPoint(x: 170, y: 230), endRadius: 160, options: [])
    
    let purpleGlow = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.70, green: 0.35, blue: 1.0, alpha: 0.15).cgColor,
        NSColor.clear.cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    cg.drawRadialGradient(purpleGlow, startCenter: CGPoint(x: 490, y: 230), startRadius: 0, endCenter: CGPoint(x: 490, y: 230), endRadius: 160, options: [])
    cg.restoreGState()
    
    // 3. Header Title & Subtitle
    let title = "CGPU Monitor" as NSString
    let titleFont = NSFont.systemFont(ofSize: 32, weight: .bold)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white
    ]
    let titleSize = title.size(withAttributes: titleAttrs)
    title.draw(at: CGPoint(x: width / 2 - titleSize.width / 2, y: 372), withAttributes: titleAttrs)
    
    let sub = "Drag CGPU Monitor to Applications to install" as NSString
    let subFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.95)
    ]
    let subSize = sub.size(withAttributes: subAttrs)
    sub.draw(at: CGPoint(x: width / 2 - subSize.width / 2, y: 344), withAttributes: subAttrs)
    
    // 4. Two Drop Target Backplates (Left: 170, 230, Right: 490, 230)
    let plateSize: CGFloat = 144
    let leftPlate = CGRect(x: 170 - plateSize / 2, y: 230 - plateSize / 2, width: plateSize, height: plateSize)
    let rightPlate = CGRect(x: 490 - plateSize / 2, y: 230 - plateSize / 2, width: plateSize, height: plateSize)
    
    for plate in [leftPlate, rightPlate] {
        let path = CGPath(roundedRect: plate, cornerWidth: 26, cornerHeight: 26, transform: nil)
        
        // Semi-transparent frosted glass fill
        cg.addPath(path)
        cg.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        cg.fillPath()
        
        // Subtle crisp border
        cg.addPath(path)
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        cg.setLineWidth(1.5)
        cg.strokePath()
    }
    
    // 5. Connecting Neon Arrow
    cg.saveGState()
    let arrowGrad = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.90).cgColor,
        NSColor(red: 0.70, green: 0.40, blue: 1.0, alpha: 0.90).cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    
    cg.setLineWidth(5)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    
    let arrowPath = CGMutablePath()
    // Main shaft
    arrowPath.move(to: CGPoint(x: 265, y: 230))
    arrowPath.addLine(to: CGPoint(x: 395, y: 230))
    
    // Arrow Head
    arrowPath.move(to: CGPoint(x: 375, y: 246))
    arrowPath.addLine(to: CGPoint(x: 395, y: 230))
    arrowPath.addLine(to: CGPoint(x: 375, y: 214))
    
    cg.addPath(arrowPath)
    cg.replacePathWithStrokedPath()
    cg.clip()
    cg.drawLinearGradient(arrowGrad, start: CGPoint(x: 265, y: 230), end: CGPoint(x: 395, y: 230), options: [])
    cg.restoreGState()
    
    // 6. Action Tag Badge above arrow
    let badgeText = "INSTALL" as NSString
    let badgeFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.85)
    ]
    let badgeSize = badgeText.size(withAttributes: badgeAttrs)
    let badgeRect = CGRect(x: width / 2 - (badgeSize.width + 16) / 2, y: 252, width: badgeSize.width + 16, height: 18)
    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: 9, cornerHeight: 9, transform: nil)
    
    cg.addPath(badgePath)
    cg.setFillColor(NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.08).cgColor)
    cg.fillPath()
    
    cg.addPath(badgePath)
    cg.setStrokeColor(NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.25).cgColor)
    cg.setLineWidth(1)
    cg.strokePath()
    
    badgeText.draw(at: CGPoint(x: width / 2 - badgeSize.width / 2, y: 254), withAttributes: badgeAttrs)
    
    // 7. Footer Note
    let footer = "v1.1.0 · macOS 13+ · by krazyeom" as NSString
    let footerFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: footerFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.35)
    ]
    let footerSize = footer.size(withAttributes: footerAttrs)
    footer.draw(at: CGPoint(x: width / 2 - footerSize.width / 2, y: 30), withAttributes: footerAttrs)
    
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let width: CGFloat = 660
let height: CGFloat = 440

// Render 1x standard resolution image (660x440)
guard let rep1x = renderDMGBackground(width: width, height: height, scale: 1.0),
      let pngData1x = rep1x.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render 1x background")
}
try! pngData1x.write(to: URL(fileURLWithPath: "dmg_background.png"))
print("Generated dmg_background.png (660x440 @ 1x)")

// Render 2x Retina resolution image (1320x880)
guard let rep2x = renderDMGBackground(width: width, height: height, scale: 2.0),
      let pngData2x = rep2x.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render 2x background")
}
try! pngData2x.write(to: URL(fileURLWithPath: "dmg_background@2x.png"))
print("Generated dmg_background@2x.png (1320x880 @ 2x)")

// Combine into Retina-aware multi-resolution TIFF
let tiffutilTask = Process()
tiffutilTask.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutilTask.arguments = ["-cathidpicheck", "dmg_background.png", "dmg_background@2x.png", "-out", "dmg_background.tiff"]
try! tiffutilTask.run()
tiffutilTask.waitUntilExit()

if tiffutilTask.terminationStatus == 0 {
    print("Successfully assembled dmg_background.tiff (Multi-Resolution 1x + 2x)")
} else {
    fatalError("tiffutil failed with exit code \(tiffutilTask.terminationStatus)")
}

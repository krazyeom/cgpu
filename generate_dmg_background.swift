import AppKit
import CoreGraphics

func createDMGBackground() {
    let width: CGFloat = 1200
    let height: CGFloat = 800
    
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width),
        pixelsHigh: Int(height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create rep")
        return
    }
    
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // 1. Dark Luxury Gradient Background
    let bgColors = [
        NSColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(bgGrad, start: CGPoint(x: 600, y: 800), end: CGPoint(x: 600, y: 0), options: [])
    
    // 2. Subtle Glow Orbs
    cg.saveGState()
    let cyanGlow = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.12).cgColor,
        NSColor.clear.cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    cg.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: 300, y: 400), startRadius: 0, endCenter: CGPoint(x: 300, y: 400), endRadius: 280, options: [])
    
    let purpleGlow = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.7, green: 0.35, blue: 1.0, alpha: 0.12).cgColor,
        NSColor.clear.cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    cg.drawRadialGradient(purpleGlow, startCenter: CGPoint(x: 900, y: 400), startRadius: 0, endCenter: CGPoint(x: 900, y: 400), endRadius: 280, options: [])
    cg.restoreGState()
    
    // 3. Header Title & Subtitle
    let title = "CGPU Monitor" as NSString
    let titleFont = NSFont.systemFont(ofSize: 52, weight: .bold)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white
    ]
    let titleSize = title.size(withAttributes: titleAttrs)
    title.draw(at: CGPoint(x: 600 - titleSize.width / 2, y: 660), withAttributes: titleAttrs)
    
    let sub = "Drag CGPU Monitor to Applications to install" as NSString
    let subFont = NSFont.systemFont(ofSize: 24, weight: .medium)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9)
    ]
    let subSize = sub.size(withAttributes: subAttrs)
    sub.draw(at: CGPoint(x: 600 - subSize.width / 2, y: 615), withAttributes: subAttrs)
    
    // 4. Two Drop Target Backplates (Left: 300, 380, Right: 900, 380)
    let plateWidth: CGFloat = 260
    let plateHeight: CGFloat = 260
    
    let leftPlate = CGRect(x: 300 - plateWidth / 2, y: 380 - plateHeight / 2, width: plateWidth, height: plateHeight)
    let rightPlate = CGRect(x: 900 - plateWidth / 2, y: 380 - plateHeight / 2, width: plateWidth, height: plateHeight)
    
    for plate in [leftPlate, rightPlate] {
        let path = CGPath(roundedRect: plate, cornerWidth: 36, cornerHeight: 36, transform: nil)
        
        // Fill
        cg.addPath(path)
        cg.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        cg.fillPath()
        
        // Border
        cg.addPath(path)
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        cg.setLineWidth(2)
        cg.strokePath()
    }
    
    // 5. Connecting Neon Arrow
    cg.saveGState()
    let arrowGrad = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.85).cgColor,
        NSColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 0.85).cgColor
    ] as CFArray, locations: [0.0, 1.0])!
    
    cg.setLineWidth(8)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    
    // Line
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: 480, y: 380))
    arrowPath.addLine(to: CGPoint(x: 710, y: 380))
    
    // Arrow Head
    arrowPath.move(to: CGPoint(x: 680, y: 410))
    arrowPath.addLine(to: CGPoint(x: 720, y: 380))
    arrowPath.addLine(to: CGPoint(x: 680, y: 350))
    
    cg.addPath(arrowPath)
    cg.replacePathWithStrokedPath()
    cg.clip()
    cg.drawLinearGradient(arrowGrad, start: CGPoint(x: 480, y: 380), end: CGPoint(x: 720, y: 380), options: [])
    cg.restoreGState()
    
    // 6. Footer Note
    let footer = "v1.1.0 · macOS 13+ · by krazyeom" as NSString
    let footerFont = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: footerFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.4)
    ]
    let footerSize = footer.size(withAttributes: footerAttrs)
    footer.draw(at: CGPoint(x: 600 - footerSize.width / 2, y: 80), withAttributes: footerAttrs)
    
    NSGraphicsContext.restoreGraphicsState()
    
    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: "dmg_background.png"))
    print("Successfully generated dmg_background.png (1200x800 @2x)")
}

createDMGBackground()

// Gera o ícone da app: swift scripts/make_icon.swift Afina/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

// Desenha o ícone do Afina (mostrador de afinador) para um tamanho em píxeis.
func drawIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    let scale = CGFloat(pixels) / 1024
    cg.scaleBy(x: scale, y: scale)

    // Grelha de ícones do macOS: squircle de 824 com margem de 100
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).cgPath

    // Sombra
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    cg.addPath(shape); cg.setFillColor(NSColor.black.cgColor); cg.fillPath()
    cg.restoreGState()

    // Fundo em gradiente
    cg.saveGState()
    cg.addPath(shape); cg.clip()
    let colors = [NSColor(red: 0.16, green: 0.22, blue: 0.40, alpha: 1).cgColor,
                  NSColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Mostrador: arco de ±60° com marcas
    let pivot = CGPoint(x: 512, y: 330)
    let radius: CGFloat = 400
    let green = NSColor(red: 0.30, green: 0.85, blue: 0.45, alpha: 1)

    // Zona verde ao centro
    cg.setStrokeColor(green.withAlphaComponent(0.30).cgColor)
    cg.setLineWidth(36)
    cg.setLineCap(.round)
    cg.addArc(center: pivot, radius: radius + 40, startAngle: (90 - 5) * .pi / 180, endAngle: (90 + 5) * .pi / 180, clockwise: false)
    cg.strokePath()

    for step in -6...6 {
        let angle = (90 - Double(step) * 10) * .pi / 180
        let isMajor = step % 3 == 0
        let length: CGFloat = step == 0 ? 100 : isMajor ? 72 : 44
        let outer = CGPoint(x: pivot.x + radius * cos(angle), y: pivot.y + radius * sin(angle))
        let inner = CGPoint(x: pivot.x + (radius - length) * cos(angle), y: pivot.y + (radius - length) * sin(angle))
        cg.setStrokeColor(NSColor.white.withAlphaComponent(step == 0 ? 1 : isMajor ? 0.85 : 0.5).cgColor)
        cg.setLineWidth(step == 0 ? 18 : isMajor ? 14 : 9)
        cg.setLineCap(.round)
        cg.move(to: inner); cg.addLine(to: outer); cg.strokePath()
    }

    // Agulha verde, ligeiramente inclinada, com brilho
    let needleAngle = (90 - 3.0) * .pi / 180
    let tip = CGPoint(x: pivot.x + (radius - 30) * cos(needleAngle), y: pivot.y + (radius - 30) * sin(needleAngle))
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 40, color: green.withAlphaComponent(0.9).cgColor)
    cg.setStrokeColor(green.cgColor)
    cg.setLineWidth(26)
    cg.setLineCap(.round)
    cg.move(to: pivot); cg.addLine(to: tip); cg.strokePath()
    cg.restoreGState()

    // Eixo
    cg.setFillColor(NSColor.white.cgColor)
    cg.fillEllipse(in: CGRect(x: pivot.x - 42, y: pivot.y - 42, width: 84, height: 84))
    cg.setFillColor(NSColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: pivot.x - 18, y: pivot.y - 18, width: 36, height: 36))

    // Brilho subtil no topo
    let shine = [NSColor.white.withAlphaComponent(0.10).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
    let shineGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: shine, locations: [0, 1])!
    cg.drawLinearGradient(shineGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! drawIcon(pixels: size * scale).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: output.appendingPathComponent("Contents.json"))
print("ok")

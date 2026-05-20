import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconImage {
    let filename: String
    let size: Int
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

let images: [IconImage] = [
    .init(filename: "iphone-notification-20@2x.png", size: 40),
    .init(filename: "iphone-notification-20@3x.png", size: 60),
    .init(filename: "iphone-settings-29@2x.png", size: 58),
    .init(filename: "iphone-settings-29@3x.png", size: 87),
    .init(filename: "iphone-spotlight-40@2x.png", size: 80),
    .init(filename: "iphone-spotlight-40@3x.png", size: 120),
    .init(filename: "iphone-app-60@2x.png", size: 120),
    .init(filename: "iphone-app-60@3x.png", size: 180),
    .init(filename: "ipad-notification-20@1x.png", size: 20),
    .init(filename: "ipad-notification-20@2x.png", size: 40),
    .init(filename: "ipad-settings-29@1x.png", size: 29),
    .init(filename: "ipad-settings-29@2x.png", size: 58),
    .init(filename: "ipad-spotlight-40@1x.png", size: 40),
    .init(filename: "ipad-spotlight-40@2x.png", size: 80),
    .init(filename: "ipad-app-76@1x.png", size: 76),
    .init(filename: "ipad-app-76@2x.png", size: 152),
    .init(filename: "ipad-pro-83.5@2x.png", size: 167),
    .init(filename: "ios-marketing-1024@1x.png", size: 1024)
]

func color(_ hex: UInt32) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255.0
    let green = CGFloat((hex >> 8) & 0xff) / 255.0
    let blue = CGFloat(hex & 0xff) / 255.0
    return CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func drawIcon(in context: CGContext, size: CGFloat) {
    let scale = size / 1024.0
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    context.setFillColor(color(0x16824E))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.setStrokeColor(color(0xF8FFF7))
    context.setLineWidth(s(58))

    let leftPage = CGMutablePath()
    leftPage.move(to: CGPoint(x: s(512), y: s(724)))
    leftPage.addCurve(
        to: CGPoint(x: s(260), y: s(654)),
        control1: CGPoint(x: s(428), y: s(648)),
        control2: CGPoint(x: s(342), y: s(628))
    )
    leftPage.addLine(to: CGPoint(x: s(260), y: s(332)))
    leftPage.addCurve(
        to: CGPoint(x: s(512), y: s(402)),
        control1: CGPoint(x: s(348), y: s(304)),
        control2: CGPoint(x: s(446), y: s(326))
    )
    context.addPath(leftPage)
    context.strokePath()

    let rightPage = CGMutablePath()
    rightPage.move(to: CGPoint(x: s(512), y: s(724)))
    rightPage.addCurve(
        to: CGPoint(x: s(764), y: s(654)),
        control1: CGPoint(x: s(596), y: s(648)),
        control2: CGPoint(x: s(682), y: s(628))
    )
    rightPage.addLine(to: CGPoint(x: s(764), y: s(332)))
    rightPage.addCurve(
        to: CGPoint(x: s(512), y: s(402)),
        control1: CGPoint(x: s(676), y: s(304)),
        control2: CGPoint(x: s(578), y: s(326))
    )
    context.addPath(rightPage)
    context.strokePath()

    context.setStrokeColor(color(0xBFEFCF))
    context.setLineWidth(s(72))

    let trail = CGMutablePath()
    trail.move(to: CGPoint(x: s(340), y: s(574)))
    trail.addCurve(
        to: CGPoint(x: s(496), y: s(656)),
        control1: CGPoint(x: s(402), y: s(604)),
        control2: CGPoint(x: s(456), y: s(628))
    )
    trail.addCurve(
        to: CGPoint(x: s(704), y: s(410)),
        control1: CGPoint(x: s(576), y: s(570)),
        control2: CGPoint(x: s(646), y: s(488))
    )
    context.addPath(trail)
    context.strokePath()

    context.setFillColor(color(0xBFEFCF))
    context.fillEllipse(in: CGRect(x: s(660), y: s(354), width: s(112), height: s(112)))
}

func makeImage(size: Int) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Could not create bitmap context")
    }
    drawIcon(in: context, size: CGFloat(size))
    guard let image = context.makeImage() else {
        fatalError("Could not render icon")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fatalError("Could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG")
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for image in images {
    let rendered = makeImage(size: image.size)
    writePNG(rendered, to: outputDirectory.appendingPathComponent(image.filename))
}

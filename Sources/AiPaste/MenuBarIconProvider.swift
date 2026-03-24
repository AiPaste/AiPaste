import AppKit

enum MenuBarIconProvider {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            let scaleX = rect.width / 18.0
            let scaleY = rect.height / 18.0
            context.saveGState()
            context.scaleBy(x: scaleX, y: scaleY)
            drawIcon(in: context)
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func drawIcon(in context: CGContext) {
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        let color = NSColor.black

        drawCard(
            in: context,
            rect: CGRect(x: 2.2, y: 2.6, width: 10.9, height: 12.2),
            radius: 3.2,
            color: color.withAlphaComponent(0.34).cgColor
        )
        drawCard(
            in: context,
            rect: CGRect(x: 4.6, y: 3.8, width: 11.2, height: 12.6),
            radius: 3.2,
            color: color.cgColor
        )
        drawCard(
            in: context,
            rect: CGRect(x: 7.0, y: 13.0, width: 6.0, height: 3.1),
            radius: 1.55,
            color: color.cgColor
        )
    }

    private static func drawCard(in context: CGContext, rect: CGRect, radius: CGFloat, color: CGColor) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
    }
}

import AppKit

/// Draws the status item's contents as a single template image.
///
/// `MenuBarExtra` flattens its label, and a `Text` with an interpolated `Image` can come out
/// blank. Compositing the symbol and the readout into one `NSImage` marked `isTemplate` is the
/// reliable route: AppKit then tints it for light/dark menu bars and for the highlighted state.
enum StatusItemImage {

    static func make(symbol: String, text: String) -> NSImage {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,  // template images are recolored by AppKit
        ]

        let glyphSize = glyph?.size ?? .zero
        let textSize = text.isEmpty ? .zero : (text as NSString).size(withAttributes: attributes)
        let gap: CGFloat = text.isEmpty ? 0 : 5
        let height: CGFloat = 18
        let size = NSSize(width: ceil(glyphSize.width + gap + textSize.width), height: height)

        guard size.width > 0 else { return NSImage(size: NSSize(width: 1, height: height)) }

        let image = NSImage(size: size, flipped: false) { _ in
            glyph?.draw(in: NSRect(x: 0,
                                   y: (height - glyphSize.height) / 2,
                                   width: glyphSize.width,
                                   height: glyphSize.height))
            if !text.isEmpty {
                (text as NSString).draw(
                    at: NSPoint(x: glyphSize.width + gap, y: (height - textSize.height) / 2),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

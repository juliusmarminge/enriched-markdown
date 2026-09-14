import SwiftUI

/// Type families bundled for the Article screen.
///
/// Space Grotesk fronts the page: the headline, section headings, every label
/// and the byline strip are set in it, so the article opens like a dispatch
/// rather than a magazine spread. Newsreader carries only the running prose —
/// KaTeX typesets math in a Computer Modern-like serif, so serif body text
/// lets the formulas sit inside a paragraph instead of looking pasted onto it.
///
/// Names are PostScript names; the files ship in `Resources/Fonts`.
enum ArticleFont {
    /// Headline and section headings.
    static let display = "SpaceGrotesk-Medium"
    static let serif = "Newsreader-Regular"
    static let serifItalic = "Newsreader-Italic"
    static let serifSemibold = "Newsreader-SemiBold"
    static let label = "SpaceGrotesk-Medium"
    static let meta = "SpaceGrotesk-Regular"
}

extension Font {
    /// Grotesk medium at headline size.
    static func articleDisplay(_ size: CGFloat) -> Font {
        .custom(ArticleFont.display, size: size)
    }

    static func articleSerif(_ size: CGFloat) -> Font {
        .custom(ArticleFont.serif, size: size)
    }

    static func articleSerifItalic(_ size: CGFloat) -> Font {
        .custom(ArticleFont.serifItalic, size: size)
    }

    /// Grotesk medium, for tracked-out labels and names.
    static func articleLabel(_ size: CGFloat) -> Font {
        .custom(ArticleFont.label, size: size)
    }

    /// Grotesk regular, for the deck, captions and secondary metadata.
    static func articleMeta(_ size: CGFloat) -> Font {
        .custom(ArticleFont.meta, size: size)
    }
}

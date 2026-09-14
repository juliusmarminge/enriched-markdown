import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// Palette for the Article screen: cool paper, near-black ink and a single
/// cobalt accent, in a light cut (the default) and a deep-navy dark cut.
///
/// Two explicit sets rather than semantic colors: `foregroundStyle(Color)`
/// resolves to a static `UIColor` at theme-build time, so a light/dark swap has
/// to come from rebuilding the theme. The article also wants a tinted paper
/// ground that `UIColor.systemBackground` does not provide.
struct ArticlePalette: Equatable {
    /// Page ground.
    let paper: Color
    /// Raised-but-quiet ground: the colophon card, chips, table stripes.
    let surface: Color
    /// Alternating table rows — one step from `paper`, never two.
    let surfaceAlt: Color
    let body: Color
    let heading: Color
    let muted: Color
    let rule: Color
    /// Kicker chip, table header, links, bullets — the one saturated color.
    let accent: Color
    /// The accent where it decorates rather than signals: the quote bar.
    let accentSoft: Color
    /// The accent diluted into the paper: inline code and display math grounds.
    let accentWash: Color
    /// Marker wash behind a highlighted span, one step past `accentWash`.
    let highlight: Color
    /// Ink on that wash: the accent deepened, so the span reads as emphasis
    /// and not merely as a colored rectangle.
    let highlightInk: Color
    let codeText: Color
    let codeBackground: Color
    let codeBorder: Color

    static let light = ArticlePalette(
        paper: Color(red: 246 / 255, green: 248 / 255, blue: 251 / 255),
        surface: Color(red: 232 / 255, green: 237 / 255, blue: 245 / 255),
        surfaceAlt: Color(red: 238 / 255, green: 242 / 255, blue: 248 / 255),
        body: Color(red: 31 / 255, green: 38 / 255, blue: 51 / 255),
        heading: Color(red: 11 / 255, green: 18 / 255, blue: 32 / 255),
        muted: Color(red: 102 / 255, green: 113 / 255, blue: 138 / 255),
        rule: Color(red: 211 / 255, green: 218 / 255, blue: 230 / 255),
        accent: Color(red: 42 / 255, green: 86 / 255, blue: 232 / 255),
        accentSoft: Color(red: 92 / 255, green: 124 / 255, blue: 242 / 255),
        accentWash: Color(red: 228 / 255, green: 234 / 255, blue: 252 / 255),
        highlight: Color(red: 214 / 255, green: 224 / 255, blue: 255 / 255),
        highlightInk: Color(red: 18 / 255, green: 36 / 255, blue: 94 / 255),
        codeText: Color(red: 228 / 255, green: 233 / 255, blue: 243 / 255),
        codeBackground: Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255),
        codeBorder: Color(red: 34 / 255, green: 48 / 255, blue: 75 / 255)
    )

    static let dark = ArticlePalette(
        paper: Color(red: 10 / 255, green: 16 / 255, blue: 32 / 255),
        surface: Color(red: 19 / 255, green: 28 / 255, blue: 49 / 255),
        surfaceAlt: Color(red: 15 / 255, green: 23 / 255, blue: 40 / 255),
        body: Color(red: 200 / 255, green: 209 / 255, blue: 227 / 255),
        heading: Color(red: 241 / 255, green: 244 / 255, blue: 250 / 255),
        muted: Color(red: 126 / 255, green: 138 / 255, blue: 166 / 255),
        rule: Color(red: 32 / 255, green: 44 / 255, blue: 72 / 255),
        accent: Color(red: 110 / 255, green: 141 / 255, blue: 255 / 255),
        accentSoft: Color(red: 78 / 255, green: 111 / 255, blue: 232 / 255),
        accentWash: Color(red: 21 / 255, green: 31 / 255, blue: 61 / 255),
        highlight: Color(red: 27 / 255, green: 43 / 255, blue: 99 / 255),
        highlightInk: Color(red: 220 / 255, green: 229 / 255, blue: 255 / 255),
        codeText: Color(red: 214 / 255, green: 222 / 255, blue: 236 / 255),
        codeBackground: Color(red: 5 / 255, green: 9 / 255, blue: 20 / 255),
        codeBorder: Color(red: 27 / 255, green: 39 / 255, blue: 66 / 255)
    )

    static func forScheme(_ scheme: ColorScheme) -> ArticlePalette {
        scheme == .dark ? .dark : .light
    }
}

/// The article's markdown theme: Newsreader prose under Space Grotesk
/// headings, one cobalt accent, and a 30pt baseline the page is measured
/// against.
///
/// `figureHeight` is the rendered height of block images. Attachments take a
/// fixed height rather than an aspect ratio, so the caller measures the text
/// column and passes the height the figures were drawn for.
func ArticleMarkdownTheme(_ palette: ArticlePalette, figureHeight: CGFloat) -> MarkdownTheme {
    MarkdownTheme {
        Paragraph()
            .fontFamily(ArticleFont.serif, size: 18)
            .foregroundStyle(palette.body)
            .lineHeight(30)
            .marginBottom(20)

        // Grotesk section heads against serif prose: the heading is a label
        // for the section, not a louder line of it.
        Heading(2)
            .fontFamily(ArticleFont.display, size: 23)
            .foregroundStyle(palette.heading)
            .lineHeight(30)
            .marginTop(40)
            .marginBottom(12)

        Heading(3)
            .fontFamily(ArticleFont.display, size: 18)
            .foregroundStyle(palette.heading)
            .lineHeight(26)
            .marginTop(30)
            .marginBottom(8)

        // Upright, a size up, on bare paper behind a solid cobalt bar — a
        // pull quote rather than a boxed aside.
        Blockquote()
            .fontFamily(ArticleFont.serif, size: 19)
            .foregroundStyle(palette.body)
            .lineHeight(31)
            .borderColor(palette.accent)
            .borderWidth(3)
            .gapWidth(18)
            .marginTop(8)
            .marginBottom(26)

        List()
            .fontFamily(ArticleFont.serif, size: 18)
            .foregroundStyle(palette.body)
            .lineHeight(30)
            .bulletColor(palette.accent)
            .bulletSize(6)
            .markerColor(palette.accent)
            .markerMinWidth(20)
            .gapWidth(12)
            .marginLeft(18)
            .marginBottom(24)

        // Solid cobalt header band with paper-colored labels; the rows below
        // stay quiet so the band is the only weight in the table.
        Table()
            .fontFamily(ArticleFont.serif, size: 15)
            .foregroundStyle(palette.body)
            .lineHeight(25)
            .headerFontFamily(ArticleFont.label, size: 12)
            .headerTextColor(palette.paper)
            .headerBackground(palette.accent)
            .rowEvenBackground(palette.surfaceAlt)
            .rowOddBackground(palette.paper)
            .borderColor(palette.rule)
            .borderWidth(1)
            .borderRadius(8)
            .cellPaddingHorizontal(14)
            .cellPaddingVertical(11)
            .marginTop(8)
            .marginBottom(28)

        // `CodeBlock.fontSize` already pins the monospaced design. Navy ground
        // in both cuts: the one deliberately dark panel on the light page.
        CodeBlock()
            .fontSize(13.5)
            .foregroundStyle(palette.codeText)
            .backgroundStyle(palette.codeBackground)
            .borderColor(palette.codeBorder)
            .borderWidth(1)
            .borderRadius(10)
            .padding(18)
            .lineHeight(22)
            .marginTop(6)
            .marginBottom(28)

        // `Code` already defaults `fontDesign` to `.monospaced`.
        Code()
            .foregroundStyle(palette.accent)
            .backgroundStyle(palette.accentWash)

        BlockImage()
            .height(figureHeight)
            .borderRadius(8)
            .marginTop(10)
            .marginBottom(10)

        // Cobalt carries the link on its own; no underline.
        Link()
            .foregroundStyle(palette.accent)
            .underline(false)

        Strong()
            .foregroundStyle(palette.heading)

        ThematicBreak()
            .color(palette.rule)
            .height(1)
            .marginTop(40)
            .marginBottom(32)

        // Display math sits on the accent wash — the same ground as inline
        // code, so formula and code read as the same kind of object. The
        // panel also bounds the region a long formula scrolls within, so a
        // clipped edge reads as more-to-the-right, not as a rendering fault.
        MathBlock()
            .fontSize(19)
            .foregroundStyle(palette.heading)
            .background(palette.accentWash)
            .padding(16)
            .marginTop(4)
            .marginBottom(20)
            .textAlignment(.center)

        InlineMath()
            .foregroundStyle(palette.body)

        // The wash is painted over the whole 30pt line box, so it stays one
        // step from the paper; the deepened ink does the emphasizing.
        Highlight()
            .foregroundStyle(palette.highlightInk)
            .background(palette.highlight)
    }
}

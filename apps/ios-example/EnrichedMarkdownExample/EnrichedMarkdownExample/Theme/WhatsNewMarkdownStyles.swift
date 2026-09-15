import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// Colors for the What's New screen: a clean white ground, the library's
/// navy as the one strong color — the header block, the source panes, every
/// signal — and its mint wherever something glows or is washed.
struct WhatsNewPalette {
    let ground = Color(red: 247 / 255, green: 247 / 255, blue: 245 / 255)
    let card = Color.white
    /// The dark pane the markdown source is printed in.
    let pane = Color(red: 8 / 255, green: 18 / 255, blue: 66 / 255)
    let paneText = Color(red: 214 / 255, green: 236 / 255, blue: 223 / 255)
    let ink = Color(red: 20 / 255, green: 22 / 255, blue: 30 / 255)
    let body = Color(red: 46 / 255, green: 49 / 255, blue: 58 / 255)
    let muted = Color(red: 112 / 255, green: 117 / 255, blue: 130 / 255)
    let rule = Color(red: 232 / 255, green: 233 / 255, blue: 236 / 255)
    /// Sunken ground for display math on the white card.
    let well = Color(red: 240 / 255, green: 242 / 255, blue: 249 / 255)
    /// Brand navy: header, links, bullets, numbers, spoiler particles.
    let accent = Color.brandNavy
    /// Brand mint: chip, number badge, highlighter wash, colophon label.
    let mint = Color.brandMint
    let highlightInk = Color.brandNavy
    let note = Color(red: 43 / 255, green: 108 / 255, blue: 222 / 255)
    let tip = Color(red: 28 / 255, green: 140 / 255, blue: 84 / 255)
    let important = Color(red: 118 / 255, green: 74 / 255, blue: 212 / 255)
    let warning = Color(red: 196 / 255, green: 128 / 255, blue: 12 / 255)
    let caution = Color(red: 206 / 255, green: 58 / 255, blue: 48 / 255)
}

/// Theme for the feature cards: Newsreader prose on the white card, navy
/// where something signals, mint where something is washed.
func WhatsNewMarkdownTheme(_ palette: WhatsNewPalette) -> MarkdownTheme {
    MarkdownTheme {
        Paragraph()
            .fontFamily(ArticleFont.serif, size: 17)
            .foregroundStyle(palette.body)
            .lineHeight(28)
            .marginBottom(14)

        Strong()
            .foregroundStyle(palette.ink)

        Link()
            .foregroundStyle(palette.accent)
            .underline(false)

        Code()
            .foregroundStyle(palette.accent)
            .backgroundStyle(palette.well)

        MathBlock()
            .fontSize(21)
            .foregroundStyle(palette.ink)
            .background(palette.well)
            .padding(14)
            .marginTop(4)
            .marginBottom(6)
            .textAlignment(.center)

        InlineMath()
            .foregroundStyle(palette.ink)

        Highlight()
            .foregroundStyle(palette.highlightInk)
            .background(palette.mint)

        Spoiler()
            .color(palette.accent)
            .background(palette.card)

        Blockquote()
            .fontFamily(ArticleFont.serif, size: 16)
            .foregroundStyle(palette.body)
            .lineHeight(26)
            .borderColor(palette.accent)
            .borderWidth(3)
            .gapWidth(14)
            .padding(12)
            .marginTop(2)
            .marginBottom(12)

        whatsNewAdmonitions(palette)

        List()
            .fontFamily(ArticleFont.serif, size: 17)
            .foregroundStyle(palette.body)
            .lineHeight(28)
            .bulletColor(palette.accent)
            .markerColor(palette.accent)
            .marginLeft(4)
            .gapWidth(10)
            .marginBottom(6)
    }
}

private func whatsNewAdmonitions(_ palette: WhatsNewPalette) -> MarkdownThemeGroup {
    let tints: [(AdmonitionType, Color)] = [
        (.note, palette.note),
        (.tip, palette.tip),
        (.important, palette.important),
        (.warning, palette.warning),
        (.caution, palette.caution)
    ]
    return MarkdownThemeGroup(contents: tints.map { type, tint in
        Admonition(type)
            .foregroundStyle(tint)
            .background(tint.opacity(0.08))
    })
}

/// Theme for the source pane: one fenced code block in the library's own
/// renderer, navy with mint-tinted mono text, no border, and no margins so
/// the card's spacing is the only spacing.
func WhatsNewSourceTheme(_ palette: WhatsNewPalette) -> MarkdownTheme {
    MarkdownTheme {
        CodeBlock()
            .fontSize(12.5, weight: .medium)
            .foregroundStyle(palette.paneText)
            .backgroundStyle(palette.pane)
            .borderWidth(0)
            .borderRadius(14)
            .padding(14)
            .lineHeight(19)
            .marginTop(0)
            .marginBottom(0)
    }
}

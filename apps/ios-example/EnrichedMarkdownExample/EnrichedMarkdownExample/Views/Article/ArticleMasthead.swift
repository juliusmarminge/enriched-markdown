import SwiftUI

/// The opening spread, cover-first: the full-bleed hero with its caption on a
/// scrim, then the kicker chip, headline, deck and the byline strip that hands
/// off to the markdown body.
struct ArticleMasthead: View {
    // MARK: - Properties

    let article: Article
    let palette: ArticlePalette
    let gutter: CGFloat
    /// The scroll view's offset from rest: positive while the page is pulled
    /// down past its top, negative once it has been scrolled. Drives the hero.
    let scrollOffset: CGFloat
    /// Flips once after the screen appears; the spread reveals itself in
    /// order, hero first, byline last.
    let appeared: Bool

    // MARK: - Views

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleHeroFigure(
                imageName: article.heroImageName,
                caption: article.heroCaption,
                palette: palette,
                gutter: gutter,
                pull: max(scrollOffset, 0),
                travelled: max(-scrollOffset, 0)
            )
            .modifier(Reveal(appeared: appeared, order: 0, rise: 0))

            kicker
                .padding(.horizontal, gutter)
                .padding(.top, 22)
                .modifier(Reveal(appeared: appeared, order: 1))

            Text(article.title)
                .font(.articleDisplay(38))
                .tracking(-1.1)
                .foregroundStyle(palette.heading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 14)
                .modifier(Reveal(appeared: appeared, order: 2))

            Text(article.deck)
                .font(.articleMeta(17))
                .lineSpacing(5)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 12)
                .modifier(Reveal(appeared: appeared, order: 3))

            ArticleBylineStrip(article: article, palette: palette)
                .padding(.horizontal, gutter)
                .padding(.top, 24)
                .modifier(Reveal(appeared: appeared, order: 4))
        }
    }

    /// Solid cobalt chip: the section label as a stamp, not a running head.
    private var kicker: some View {
        Text(article.kicker.uppercased())
            .font(.articleLabel(10))
            .tracking(1.6)
            .foregroundStyle(palette.paper)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(palette.accent))
    }
}

// MARK: -

/// Fades a piece of the masthead in and lifts it into place, `order` steps
/// after the one before it.
private struct Reveal: ViewModifier {
    let appeared: Bool
    let order: Int
    var rise: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : rise)
            .animation(.easeOut(duration: 0.55).delay(0.08 * Double(order)), value: appeared)
    }
}

// MARK: -

/// Byline as a spec sheet: two labelled cells between hairlines, the author's
/// monogram as a square tag at the head of the row.
struct ArticleBylineStrip: View {
    // MARK: - Properties

    let article: Article
    let palette: ArticlePalette

    // MARK: - Views

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.rule)
                .frame(height: 1)

            HStack(spacing: 0) {
                HStack(spacing: 11) {
                    monogram
                    cell("Written by", article.authorName)
                }

                Spacer(minLength: 14)

                Rectangle()
                    .fill(palette.rule)
                    .frame(width: 1)
                    .padding(.vertical, 2)

                Spacer(minLength: 14)

                cell("Published", "\(article.publishedOn) · \(article.readingTime)")
            }
            .padding(.vertical, 14)
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(palette.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var monogram: some View {
        Text(article.authorInitials)
            .font(.articleLabel(12))
            .tracking(0.4)
            .foregroundStyle(palette.paper)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.accent))
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.articleLabel(9.5))
                .tracking(1.3)
                .foregroundStyle(palette.muted)

            Text(value)
                .font(.articleLabel(13))
                .foregroundStyle(palette.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

// MARK: -

/// Edge-to-edge hero image that answers the scroll.
///
/// Pulled past the top, it stretches to fill the gap and zooms with it, so the
/// page never shows a seam above the picture. Scrolled away, it drifts at a
/// fraction of the content's speed and dims as the article covers it, and the
/// caption fades out ahead of it. All of it is a function of the offset, so
/// there is nothing to animate and nothing to catch up.
struct ArticleHeroFigure: View {
    // MARK: - Properties

    let imageName: String
    let caption: String
    let palette: ArticlePalette
    let gutter: CGFloat
    /// Distance the page has been pulled past its top.
    let pull: CGFloat
    /// Distance the page has been scrolled from rest.
    let travelled: CGFloat

    private let height: CGFloat = 268
    /// Fraction of the content's speed the image gives up to the parallax.
    private let drift: CGFloat = 0.42

    /// 0 at rest, 1 once the image has scrolled out of the window.
    private var leaving: CGFloat {
        min(travelled / height, 1)
    }

    /// The caption goes ahead of the picture, gone by a third of the way out.
    private var captionOpacity: Double {
        Double(max(1 - leaving * 1.8, 0))
    }

    // MARK: - Views

    var body: some View {
        GeometryReader { frame in
            ZStack(alignment: .bottom) {
                image
                    .offset(y: travelled * drift)
                    .frame(width: frame.size.width, height: height + pull)
                    .clipped()
                    .overlay(Color.black.opacity(leaving * 0.5))

                figureLine
                    .padding(.horizontal, gutter)
                    .padding(.top, 56)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(scrim)
                    .opacity(captionOpacity)
            }
            // The stretch overflows upward, out of a window that stays the
            // same height in layout, so nothing below the hero moves with it.
            .frame(width: frame.size.width, height: height, alignment: .bottom)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var image: some View {
        if let hero = Image(bundledPNG: imageName) {
            hero.resizable().scaledToFill()
        } else {
            palette.surface
        }
    }

    private var figureLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("FIG. 1")
                .font(.articleLabel(10))
                .tracking(1.3)

            Text(caption)
                .font(.articleMeta(12))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    /// Fades from nothing above the caption to a readable dark foot.
    private var scrim: some View {
        LinearGradient(
            colors: [.black.opacity(0), .black.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: -

#Preview {
    ScrollView {
        ArticleMasthead(
            article: .featured,
            palette: .light,
            gutter: 24,
            scrollOffset: 0,
            appeared: true
        )
    }
    .background(ArticlePalette.light.paper)
}

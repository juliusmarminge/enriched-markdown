import SwiftUI

/// The opening spread, cover-first: the full-bleed hero with its caption on a
/// scrim, then the kicker chip, headline, deck and the byline strip that hands
/// off to the markdown body.
struct ArticleMasthead: View {
    // MARK: - Properties

    let article: Article
    let palette: ArticlePalette
    let gutter: CGFloat
    /// Viewport size, used by the hero's parallax instead of `UIScreen`.
    let viewport: CGSize

    // MARK: - Views

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleHeroFigure(
                imageName: article.heroImageName,
                caption: article.heroCaption,
                palette: palette,
                gutter: gutter,
                viewport: viewport
            )

            kicker
                .padding(.horizontal, gutter)
                .padding(.top, 22)

            Text(article.title)
                .font(.articleDisplay(38))
                .tracking(-1.1)
                .foregroundStyle(palette.heading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 14)

            Text(article.deck)
                .font(.articleMeta(17))
                .lineSpacing(5)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 12)

            ArticleBylineStrip(article: article, palette: palette)
                .padding(.horizontal, gutter)
                .padding(.top, 24)
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

/// Edge-to-edge hero image with a light parallax; the figure line is printed
/// on a scrim over its foot, the way a cover credits its photograph.
///
/// The image is drawn taller than its window and slid against the scroll, so
/// it drifts rather than tracks — enough to read as depth, not as motion.
struct ArticleHeroFigure: View {
    // MARK: - Properties

    let imageName: String
    let caption: String
    let palette: ArticlePalette
    let gutter: CGFloat
    let viewport: CGSize

    private let height: CGFloat = 268
    private let overdraw: CGFloat = 72

    // MARK: - Views

    var body: some View {
        GeometryReader { frame in
            image
                .frame(width: frame.size.width, height: height + overdraw)
                .offset(y: parallax(midY: frame.frame(in: .global).midY))
                .frame(width: frame.size.width, height: height)
                .clipped()
                .overlay(alignment: .bottom) {
                    figureLine
                        .padding(.horizontal, gutter)
                        .padding(.top, 56)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(scrim)
                }
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

    // MARK: - Methods

    /// Half the overdraw at most, so the image never uncovers its window.
    private func parallax(midY: CGFloat) -> CGFloat {
        let limit = overdraw / 2
        let travel = (midY - viewport.height / 2) / max(viewport.height, 1)
        return min(max(travel * limit, -limit), limit)
    }
}

// MARK: -

#Preview {
    ScrollView {
        ArticleMasthead(
            article: .featured,
            palette: .light,
            gutter: 24,
            viewport: CGSize(width: 393, height: 852)
        )
    }
    .background(ArticlePalette.light.paper)
}

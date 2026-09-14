import SwiftUI

/// Foot of the page: a card carrying the library's mark and one line on what
/// was rendered above it.
struct ArticleColophon: View {
    // MARK: - Properties

    let palette: ArticlePalette
    let gutter: CGFloat

    // MARK: - Views

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            mark

            VStack(alignment: .leading, spacing: 5) {
                Text("ENRICHED MARKDOWN")
                    .font(.articleLabel(11))
                    .tracking(1.7)
                    .foregroundStyle(palette.accent)

                Text("Prose, LaTeX, figures, tables and code — one markdown source, rendered natively on iOS.")
                    .font(.articleMeta(12))
                    .lineSpacing(4)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.surface))
        .padding(.horizontal, gutter)
    }

    @ViewBuilder
    private var mark: some View {
        if let logo = Image(bundledPNG: "logo_icon") {
            logo
                .resizable()
                .frame(width: 24, height: 24)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.paper))
        }
    }
}

// MARK: -

#Preview {
    ArticleColophon(palette: .light, gutter: 24)
        .background(ArticlePalette.light.paper)
}

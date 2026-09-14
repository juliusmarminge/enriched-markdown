import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SafariServices
import SwiftUI

/// Long-form article rendered entirely from markdown — prose, LaTeX math, a
/// figure, GitHub alerts, a table and a code block — to show the library
/// carrying a real document rather than a feature checklist.
///
/// The masthead and the colophon are SwiftUI; everything between them is a
/// single `EnrichedMarkdownText`, on the same cool paper and the same 30pt
/// baseline, so the seam between app chrome and rendered markdown disappears.
struct ArticleScreen: View {
    // MARK: - Properties

    let article: Article

    @Environment(\.colorScheme) private var systemColorScheme
    /// Light by default: the page is designed on cool paper and a recording
    /// should open on it whatever the device is set to. The navy cut in
    /// `ArticlePalette.dark` is there for when this is switched to `nil`.
    @State private var schemeOverride: ColorScheme? = .light
    @State private var presentedLink: PresentedLink?
    @State private var scrollOffset: CGFloat = 0
    @State private var hasAppeared: Bool = false

    private static let scrollSpace = "article-scroll"
    /// Text column margin, and the width block figures are measured against.
    private static let gutter: CGFloat = 24
    /// Aspect ratio both bundled figures were drawn at.
    private static let figureRatio: CGFloat = 0.52

    private var effectiveScheme: ColorScheme {
        schemeOverride ?? systemColorScheme
    }

    private var palette: ArticlePalette {
        ArticlePalette.forScheme(effectiveScheme)
    }

    private var travelled: CGFloat {
        max(-scrollOffset, 0)
    }

    // MARK: - Views

    var body: some View {
        GeometryReader { viewport in
            let columnWidth = viewport.size.width - Self.gutter * 2

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    offsetSentinel

                    ArticleMasthead(
                        article: article,
                        palette: palette,
                        gutter: Self.gutter,
                        scrollOffset: scrollOffset,
                        appeared: hasAppeared
                    )

                    ArticleBody(
                        markdown: article.body,
                        palette: palette,
                        figureHeight: (columnWidth * Self.figureRatio).rounded(),
                        gutter: Self.gutter,
                        onLinkPress: open(link:)
                    )
                    .equatable()

                    ArticleColophon(palette: palette, gutter: Self.gutter)
                        .padding(.bottom, 72)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: Self.scrollSpace)
            .modifier(ArticleScrollTracking(scrollOffset: $scrollOffset))
        }
        .background(palette.paper.ignoresSafeArea())
        .markdownSelectionColor(palette.accent.opacity(0.28))
        .preferredColorScheme(schemeOverride)
        .tint(palette.accent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(effectiveScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(article.title)
                    .font(.articleLabel(15))
                    .foregroundStyle(palette.heading)
                    .opacity(runningTitleOpacity)
                    .accessibilityHidden(runningTitleOpacity < 0.5)
            }
        }
        .onAppear {
            hasAppeared = true
        }
        .sheet(item: $presentedLink) { link in
            ArticleLinkSheet(url: link.url, tint: palette.accent)
                .ignoresSafeArea()
        }
    }

    /// Zero-height probe: its distance from the top of the scroll view is how
    /// far the article has been read. Read by `ArticleScrollTracking` on
    /// iOS 16 and 17; later systems take the offset from the scroll view.
    private var offsetSentinel: some View {
        GeometryReader { frame in
            Color.clear.preference(
                key: ArticleScrollOffsetKey.self,
                value: frame.frame(in: .named(Self.scrollSpace)).minY
            )
        }
        .frame(height: 0)
    }

    // MARK: - Methods

    /// The running head takes over once the printed headline has scrolled off.
    private var runningTitleOpacity: Double {
        Double(min(max((travelled - 360) / 56, 0), 1))
    }

    /// Web links open in an in-app Safari sheet; anything else goes to the
    /// system.
    private func open(link url: URL) {
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            presentedLink = PresentedLink(url: url)
        } else {
            UIApplication.shared.open(url)
        }
    }
}

/// The rendered document, isolated from the scroll-driven state on
/// `ArticleScreen`.
///
/// Reading progress updates `scrollOffset` on every frame of a scroll, which
/// re-evaluates the screen's `body`. Inline, that rebuilt the markdown theme
/// and re-drove `EnrichedMarkdownText` 60 times a second — one core pegged for
/// the length of the gesture. Nothing here depends on the scroll position, so
/// `Equatable` lets SwiftUI skip the whole subtree until the palette or the
/// column width actually changes.
private struct ArticleBody: View, Equatable {
    let markdown: String
    let palette: ArticlePalette
    let figureHeight: CGFloat
    let gutter: CGFloat
    let onLinkPress: (URL) -> Void

    /// The closure is deliberately not compared: it is recreated on every
    /// parent evaluation and only ever presents the link sheet.
    static func == (lhs: ArticleBody, rhs: ArticleBody) -> Bool {
        lhs.markdown == rhs.markdown
            && lhs.palette == rhs.palette
            && lhs.figureHeight == rhs.figureHeight
            && lhs.gutter == rhs.gutter
    }

    var body: some View {
        EnrichedMarkdownText(markdown, flags: Md4cFlags(highlight: true, admonitions: true))
            .markdownLaTeX()
            .markdownTheme(ArticleMarkdownTheme(palette, figureHeight: figureHeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, gutter)
            .padding(.top, 28)
            .padding(.bottom, 4)
            .onLinkPress(onLinkPress)
    }
}

// MARK: -

private struct PresentedLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Safari, in a sheet, in the article's accent.
private struct ArticleLinkSheet: UIViewControllerRepresentable {
    let url: URL
    let tint: Color

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(tint)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// MARK: -

#Preview {
    NavigationStack {
        ArticleScreen(article: .featured)
    }
}

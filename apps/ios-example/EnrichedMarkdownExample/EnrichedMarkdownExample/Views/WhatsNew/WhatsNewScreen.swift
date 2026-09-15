import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// The release's additions to the iOS renderer, one card each: the feature,
/// the markdown that exercises it, and the live render of that markdown —
/// short enough to scroll in one take, and most of it answers a tap.
///
/// Set in the Article screen's faces on a white ground, bookended by two navy
/// blocks — the header and the colophon — so it reads as the renderer's
/// launch page, not another article.
///
/// A triple tap anywhere starts a guided tour for recording: the page glides
/// from card to card, resting on each for its `dwell`, longest on LaTeX so
/// the formula can be dragged and long-pressed, then visits the colophon and
/// eases back to the top. A second triple tap stops it.
struct WhatsNewScreen: View {
    // MARK: - Properties

    private let features = WhatsNewFeature.release
    private let palette = WhatsNewPalette()

    @State private var hasAppeared = false
    @State private var tour: Task<Void, Never>?

    private static let gutter: CGFloat = 20
    /// Margin the tour leaves above a card it has scrolled to.
    private static let tourLead: CGFloat = 14
    private static let topMarker = "top"
    private static let colophonMarker = "colophon"

    // MARK: - Views

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    marker(Self.topMarker)

                    masthead
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                        .modifier(Reveal(appeared: hasAppeared, order: 0))

                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        marker(feature.id)
                            .padding(.top, index == 0 ? 0 : 16 - Self.tourLead)

                        WhatsNewCard(index: index + 1, feature: feature, palette: palette)
                            .padding(.top, Self.tourLead)
                            .modifier(Reveal(appeared: hasAppeared, order: index + 1))
                    }

                    colophon
                        .padding(.top, 28)
                        .padding(.bottom, 48)
                        .id(Self.colophonMarker)
                }
                .padding(.horizontal, Self.gutter)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                TapGesture(count: 3).onEnded { toggleTour(reader) }
            )
        }
        .background(palette.ground.ignoresSafeArea())
        .markdownSelectionColor(palette.accent.opacity(0.3))
        .preferredColorScheme(.light)
        .tint(palette.accent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("What's New")
                    .font(.articleLabel(15))
                    .foregroundStyle(palette.ink)
            }
        }
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            tour?.cancel()
        }
    }

    /// Zero-height anchor the tour scrolls to; it sits `tourLead` above the
    /// card so the card lands with a margin under the bar.
    private func marker(_ id: String) -> some View {
        Color.clear
            .frame(height: 0)
            .id(id)
    }

    /// Flat navy block: the page's one loud moment.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ENRICHED MARKDOWN · IOS")
                .font(.articleLabel(10))
                .tracking(1.6)
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(palette.mint))

            Text("Four new things markdown can do")
                .font(.articleDisplay(32))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("LaTeX, highlights, spoilers and admonitions. Plain markdown in, rendered live below its source.")
                .font(.articleSerifItalic(18))
                .lineSpacing(5)
                .foregroundStyle(palette.mint.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(navyBlock)
    }

    /// The header's and the colophon's ground: solid brand navy.
    private var navyBlock: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.accent)
            .shadow(color: palette.accent.opacity(0.22), radius: 18, y: 10)
    }

    private var colophon: some View {
        HStack(alignment: .top, spacing: 14) {
            if let logo = Image(bundledPNG: "logo_icon") {
                logo
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.mint))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("ENRICHED MARKDOWN")
                    .font(.articleLabel(11))
                    .tracking(1.7)
                    .foregroundStyle(palette.mint)

                Text("One markdown source, rendered natively on iOS, macOS, Android and Web.")
                    .font(.articleMeta(12))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(navyBlock)
    }
}

// MARK: - Tour

extension WhatsNewScreen {
    private func toggleTour(_ reader: ScrollViewProxy) {
        if let tour {
            tour.cancel()
            self.tour = nil
            return
        }
        tour = Task { @MainActor in
            await runTour(reader)
            tour = nil
        }
    }

    /// Card by card, then the colophon, then home. Each leg is a slow ease
    /// so the recording never cuts.
    private func runTour(_ reader: ScrollViewProxy) async {
        for feature in features {
            glide(reader, to: feature.id, anchor: .top)
            guard await rest(feature.dwell) else { return }
        }
        glide(reader, to: Self.colophonMarker, anchor: .bottom)
        guard await rest(3) else { return }
        glide(reader, to: Self.topMarker, anchor: .top, duration: 1.2)
    }

    private func glide(_ reader: ScrollViewProxy, to id: String, anchor: UnitPoint, duration: Double = 0.9) {
        withAnimation(.easeInOut(duration: duration)) {
            reader.scrollTo(id, anchor: anchor)
        }
    }

    /// Waits out a dwell; false once the tour has been cancelled.
    private func rest(_ seconds: TimeInterval) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

// MARK: -

/// One feature: numbered title, blurb, the markdown in a sunken block, and
/// the render beneath it with an interaction cue where there is one.
private struct WhatsNewCard: View {
    let index: Int
    let feature: WhatsNewFeature
    let palette: WhatsNewPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(.articleLabel(12))
                    .tracking(0.6)
                    .foregroundStyle(palette.accent)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.mint))

                Text(feature.title)
                    .font(.articleDisplay(24))
                    .tracking(-0.5)
                    .foregroundStyle(palette.ink)
            }

            Text(feature.blurb)
                .font(.articleSerif(16))
                .lineSpacing(4)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            source

            render
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.card))
        .shadow(color: palette.accent.opacity(0.08), radius: 18, y: 8)
    }

    /// The markdown, printed in a dark pane so the card visibly goes from
    /// code to page. The pane is the library's own code block: the source is
    /// wrapped in a fence and rendered like everything else on the card.
    private var source: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("MARKDOWN")

            EnrichedMarkdownText("~~~markdown\n\(feature.source)\n~~~")
                .markdownTheme(WhatsNewSourceTheme(palette))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var render: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("RENDERED")

            EnrichedMarkdownText(feature.source, flags: Md4cFlags(highlight: true, admonitions: true))
                .markdownLaTeX()
                .markdownTheme(WhatsNewMarkdownTheme(palette))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let hint = feature.hint {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 11, weight: .medium))
                    Text(hint)
                        .font(.articleLabel(11))
                }
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.articleLabel(9.5))
            .tracking(1.4)
            .foregroundStyle(palette.muted)
    }
}

// MARK: -

/// Fades a block in and lifts it into place, `order` steps after the one
/// before it.
private struct Reveal: ViewModifier {
    let appeared: Bool
    let order: Int

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.5).delay(0.07 * Double(order)), value: appeared)
    }
}

// MARK: -

#Preview {
    NavigationStack {
        WhatsNewScreen()
    }
}

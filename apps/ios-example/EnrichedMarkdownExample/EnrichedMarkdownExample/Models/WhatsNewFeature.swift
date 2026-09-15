import Foundation

/// One card on the What's New screen: a feature, the markdown that exercises
/// it, and the gesture the demo invites.
struct WhatsNewFeature: Identifiable {
    let id: String
    let title: String
    /// One sentence on what the renderer does with it.
    let blurb: String
    /// The markdown the card renders, shown verbatim above the render.
    let source: String
    /// Interaction cue printed under the render, if the render answers touch.
    let hint: String?
    /// Seconds the guided tour rests on the card before moving on.
    let dwell: TimeInterval
}

extension WhatsNewFeature {
    /// The release's additions, each short enough to read on one screen and
    /// most of them something to touch.
    static let release: [WhatsNewFeature] = [
        WhatsNewFeature(
            id: "latex",
            title: "LaTeX",
            blurb: "Inline math sits in the sentence at the text's size. Display math gets its own block, "
                + "and a long line scrolls sideways instead of shrinking.",
            source: """
            Euler tied five constants together in $e^{i\\pi} + 1 = 0$. \
            Expanding a packet's dispersion relation about its centre:

            $$\\omega(k) = \\omega_0 + \\left. \\frac{d\\omega}{dk} \\right|_{k_0} (k - k_0) \
            + \\frac{1}{2} \\left. \\frac{d^2\\omega}{dk^2} \\right|_{k_0} (k - k_0)^2 \
            + \\mathcal{O}\\left( (k - k_0)^3 \\right)$$
            """,
            hint: "Drag the formula sideways",
            dwell: 6
        ),
        WhatsNewFeature(
            id: "highlight",
            title: "Highlights",
            blurb: "Double equals marks a span. The wash is painted over the whole line box, so the theme "
                + "sets the ink as well as the color behind it.",
            source: """
            Vacuum is non-dispersive: ==every colour travels at the same speed==, \
            which is why a distant supernova arrives as ==a flash rather than a smear==.
            """,
            hint: nil,
            dwell: 3.5
        ),
        WhatsNewFeature(
            id: "spoiler",
            title: "Spoilers",
            blurb: "Text between double bars renders hidden under a field of particles until it is tapped. "
                + "Links inside stay inert until then.",
            source: """
            The oldest known tree is ||a bristlecone pine named Methuselah|| \
            and it has stood for ||about 4,850 years||.
            """,
            hint: "Tap to reveal",
            dwell: 4
        ),
        WhatsNewFeature(
            id: "admonitions",
            title: "Admonitions",
            blurb: "GitHub's five admonition types, drawn as a tinted bar, icon and title over the quote's own "
                + "geometry, with a fill of the same hue.",
            source: """
            > [!TIP]
            > Admonitions are blockquotes that open with a type marker.

            > [!IMPORTANT]
            > Note, tip, important, warning and caution.

            > [!CAUTION]
            > Each type keeps its own color in light and dark.
            """,
            hint: nil,
            dwell: 3.5
        )
    ]
}

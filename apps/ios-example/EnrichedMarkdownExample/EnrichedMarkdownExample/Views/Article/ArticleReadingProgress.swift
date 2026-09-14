import SwiftUI

/// Floating reading indicator: a capsule in the bottom-left corner with a short
/// bar and the percentage read, kept clear of the text column.
struct ArticleReadingProgress: View {
    // MARK: - Properties

    /// 0…1, clamped by the caller.
    let progress: CGFloat
    let palette: ArticlePalette

    private let barWidth: CGFloat = 64

    // MARK: - Views

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(palette.rule)
                .frame(width: barWidth, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: barWidth * progress)
                        .animation(.linear(duration: 0.08), value: progress)
                }

            Text("\(Int((progress * 100).rounded()))%")
                .font(.articleLabel(12))
                .monospacedDigit()
                .foregroundStyle(palette.heading)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Capsule().fill(palette.paper))
        .overlay(Capsule().strokeBorder(palette.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .accessibilityHidden(true)
    }
}

// MARK: -

/// Feeds the screen's scroll offset and content height from the scroll view.
///
/// `scrollOffset` is the sentinel's `minY` in the scroll view's space — zero
/// at rest, positive while pulled past the top and increasingly negative as
/// the article is read — on every system, so the two sources below are
/// interchangeable to the caller.
///
/// From iOS 18 the scroll view reports its own geometry, which also updates
/// during a scroll on iOS 26, where a `GeometryReader` inside the content no
/// longer re-evaluates while the view is being dragged. Earlier systems fall
/// back to the preference keys the sentinel and the content background emit.
struct ArticleScrollTracking: ViewModifier {
    @Binding var scrollOffset: CGFloat
    @Binding var contentHeight: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ArticleScrollMetrics.self) { geometry in
                // Negative while pulled past the top — the hero stretches into
                // that — but capped at the end: the rubber-band past the foot
                // would otherwise re-evaluate the screen on every frame of the
                // bounce for values the page has no use for.
                let scrollable = max(geometry.contentSize.height - geometry.containerSize.height, 0)
                let travelled = geometry.contentOffset.y + geometry.contentInsets.top
                return ArticleScrollMetrics(
                    travelled: min(travelled, scrollable),
                    contentHeight: geometry.contentSize.height
                )
            } action: { _, metrics in
                scrollOffset = -metrics.travelled
                contentHeight = metrics.contentHeight
            }
        } else {
            content
                .onPreferenceChange(ArticleScrollOffsetKey.self) { scrollOffset = $0 }
                .onPreferenceChange(ArticleContentHeightKey.self) { contentHeight = $0 }
        }
    }
}

private struct ArticleScrollMetrics: Equatable {
    let travelled: CGFloat
    let contentHeight: CGFloat
}

/// Distance the article has travelled under the navigation bar, reported by a
/// zero-height sentinel at the top of the scroll content.
struct ArticleScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Height of the whole scrolled column, for the progress denominator.
struct ArticleContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

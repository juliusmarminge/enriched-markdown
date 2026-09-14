import SwiftUI

/// Feeds the screen's scroll offset from the scroll view.
///
/// `scrollOffset` is the sentinel's `minY` in the scroll view's space — zero
/// at rest, positive while pulled past the top and increasingly negative as
/// the article is read — on every system, so the two sources below are
/// interchangeable to the caller.
///
/// From iOS 18 the scroll view reports its own geometry, which keeps updating
/// during a drag where a `GeometryReader` inside the content does not (on
/// iOS 18.2 its preference only fires once the scroll settles). Earlier
/// systems fall back to the preference key the sentinel emits.
struct ArticleScrollTracking: ViewModifier {
    @Binding var scrollOffset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Negative while pulled past the top — the hero stretches into
                // that — but capped at the end: the rubber-band past the foot
                // would otherwise re-evaluate the screen on every frame of the
                // bounce for values the page has no use for.
                let scrollable = max(geometry.contentSize.height - geometry.containerSize.height, 0)
                let travelled = geometry.contentOffset.y + geometry.contentInsets.top
                return min(travelled, scrollable)
            } action: { _, travelled in
                scrollOffset = -travelled
            }
        } else {
            content.onPreferenceChange(ArticleScrollOffsetKey.self) { scrollOffset = $0 }
        }
    }
}

/// Distance the article has travelled under the navigation bar, reported by a
/// zero-height sentinel at the top of the scroll content.
struct ArticleScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

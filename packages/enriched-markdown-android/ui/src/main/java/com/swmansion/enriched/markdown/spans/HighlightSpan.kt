package com.swmansion.enriched.markdown.spans

import android.graphics.Color
import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving

/**
 * Paints the highlight background and optionally recolors the highlighted run.
 *
 * Deliberately a plain [CharacterStyle] rather than a `MetricAffectingSpan`: it must not reset
 * the typeface or text size, so nested strong/emphasis spans inside `==highlight==` keep working.
 */
class HighlightSpan(
  private val styleCache: SpanStyleCache,
) : CharacterStyle() {
  override fun updateDrawState(tp: TextPaint) {
    // A null color inherits whatever the surrounding block or a nested inline span set.
    styleCache.highlightColor?.let { tp.applyColorPreserving(it, *styleCache.colorsToPreserve) }

    val backgroundColor = styleCache.highlightBackgroundColor
    if (Color.alpha(backgroundColor) > 0) {
      tp.bgColor = backgroundColor
    }
  }
}

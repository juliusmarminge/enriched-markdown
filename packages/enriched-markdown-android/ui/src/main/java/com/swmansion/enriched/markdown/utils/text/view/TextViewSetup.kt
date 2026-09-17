package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.os.Build
import android.text.GetChars
import android.text.Spannable
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.view.textclassifier.TextClassifier
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView

/**
 * Hands the rendered buffer to [TextView][android.widget.TextView] without copying it.
 *
 * The default factory copies the text into a fresh `SpannableString` on every
 * `setText`, and `SpannableString.setSpan` scans the spans it already holds
 * before appending, so that copy costs O(spans^2) - tens of milliseconds of main
 * thread time for a long document. `Renderer` builds a private buffer per
 * segment and nothing else holds a reference to it, so the view can adopt it
 * without a defensive copy.
 *
 * A `SpannableStringBuilder` is wrapped in [InsertionOrderedSpannable] rather
 * than adopted directly, see there for why.
 */
private object NoCopySpannableFactory : Spannable.Factory() {
  override fun newSpannable(source: CharSequence): Spannable =
    when (source) {
      is SpannableStringBuilder -> InsertionOrderedSpannable(source)
      is Spannable -> source
      else -> SpannableString(source)
    }
}

/**
 * Exposes [buffer] as a plain [Spannable], hiding that it is a `SpannableStringBuilder`.
 *
 * `Layout.getParagraphSpans` special-cases `SpannableStringBuilder` and reads its
 * paragraph spans in position order instead of insertion order. Layout paints
 * `LeadingMarginSpan`s in that order, advancing x by each one's margin, and the
 * list spans place their markers assuming the innermost (first inserted) span
 * is painted first - in position order a nested checkbox lands an indent too far
 * right, over its own text and outside the tappable margin. `LineHeightSpan`s
 * are chained in that same order. Behind this wrapper Layout falls back to the
 * public `getSpans`, which keeps insertion order, as a `SpannableString` would.
 */
private class InsertionOrderedSpannable(
  private val buffer: SpannableStringBuilder,
) : Spannable,
  GetChars {
  override val length: Int get() = buffer.length

  override fun get(index: Int): Char = buffer[index]

  override fun subSequence(
    startIndex: Int,
    endIndex: Int,
  ): CharSequence = buffer.subSequence(startIndex, endIndex)

  override fun getChars(
    start: Int,
    end: Int,
    dest: CharArray,
    destoff: Int,
  ) = buffer.getChars(start, end, dest, destoff)

  override fun <T : Any?> getSpans(
    start: Int,
    end: Int,
    type: Class<T>,
  ): Array<T> = buffer.getSpans(start, end, type)

  override fun getSpanStart(tag: Any): Int = buffer.getSpanStart(tag)

  override fun getSpanEnd(tag: Any): Int = buffer.getSpanEnd(tag)

  override fun getSpanFlags(tag: Any): Int = buffer.getSpanFlags(tag)

  override fun nextSpanTransition(
    start: Int,
    limit: Int,
    type: Class<*>?,
  ): Int = buffer.nextSpanTransition(start, limit, type)

  override fun setSpan(
    what: Any,
    start: Int,
    end: Int,
    flags: Int,
  ) = buffer.setSpan(what, start, end, flags)

  override fun removeSpan(what: Any) = buffer.removeSpan(what)

  override fun toString(): String = buffer.toString()
}

fun AccessibleMarkdownTextView.setupAsMarkdownTextView() {
  setBackgroundColor(Color.TRANSPARENT)
  setSpannableFactory(NoCopySpannableFactory)
  includeFontPadding = false
  movementMethod = LinkLongPressMovementMethod.createInstance()
  setTextIsSelectable(true)
  customSelectionActionModeCallback = createSelectionActionModeCallback(this)
  // SmartSelectSprite crashes with "Center point is not inside any of the
  // rectangles!" when Layout.getSelection returns empty rects near an
  // ImageSpan (ReplacementSpan). NO_OP makes skipTextClassification() return
  // true, bypassing the entire SmartSelectSprite code path. Regular text
  // selection (long-press, handles, copy/paste) still works; only automatic
  // entity detection (phone numbers, addresses) is disabled.
  //
  // TODO: Add an Android-only `enableSmartTextSelection` prop that skips this
  // NO_OP override. This would let users who don't render images opt in to
  // entity detection. The prop should default to false and its docs should
  // warn that enabling it with markdown containing images will crash.
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    setTextClassifier(TextClassifier.NO_OP)
  }
  isVerticalScrollBarEnabled = false
  isHorizontalScrollBarEnabled = false
  ViewCompat.setAccessibilityDelegate(this, accessibilityHelper)
}

fun AppCompatTextView.applySelectableState(selectable: Boolean) {
  if (isTextSelectable == selectable) return
  setTextIsSelectable(selectable)
  movementMethod = LinkLongPressMovementMethod.createInstance()
  if (!selectable && !isClickable) isClickable = true
}

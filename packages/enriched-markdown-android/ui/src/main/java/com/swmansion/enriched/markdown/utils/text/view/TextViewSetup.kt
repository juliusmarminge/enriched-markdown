package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.os.Build
import android.text.Spannable
import android.text.SpannableString
import android.view.textclassifier.TextClassifier
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView

/**
 * Hands the rendered buffer to [TextView][android.widget.TextView] as-is.
 *
 * The default factory copies the text into a fresh `SpannableString` on every
 * `setText`, and `SpannableString.setSpan` scans the spans it already holds
 * before appending, so that copy costs O(spans^2) - tens of milliseconds of main
 * thread time for a long document. `Renderer` builds a private buffer per
 * segment and nothing else holds a reference to it, so the view can adopt it
 * without a defensive copy.
 */
private object NoCopySpannableFactory : Spannable.Factory() {
  override fun newSpannable(source: CharSequence): Spannable = source as? Spannable ?: SpannableString(source)
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

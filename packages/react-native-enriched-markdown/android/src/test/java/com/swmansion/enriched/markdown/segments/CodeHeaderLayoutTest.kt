package com.swmansion.enriched.markdown.segments

import android.graphics.Color
import android.view.View
import android.widget.HorizontalScrollView
import android.widget.TextView
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class CodeHeaderLayoutTest {
  @Test
  fun controlsAreCenteredAboveDividerAtDifferentFontSizes() {
    val context = RuntimeEnvironment.getApplication()
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)
    for (size in listOf(16.0, 32.0)) {
      val code =
        JavaOnlyMap.of(
          "fontFamily",
          "monospace",
          "fontWeight",
          "normal",
          "fontSize",
          size,
          "lineHeight",
          0.0,
          "marginTop",
          0.0,
          "marginBottom",
          0.0,
          "color",
          Color.BLACK,
          "backgroundColor",
          Color.WHITE,
          "borderColor",
          Color.TRANSPARENT,
          "borderWidth",
          0.0,
          "borderRadius",
          4.0,
          "padding",
          12.0,
        )
      val view = CodeBlockContainerView(context, StyleConfig(JavaOnlyMap.of("codeBlock", code), context, false, 0f))
      // Pending fences use the same header layout without calling the native highlighter.
      view.pending = true
      view.applyCodeBlockNode(MarkdownASTNode(MarkdownASTNode.NodeType.CodeBlock, "const answer = 42;", mapOf("info" to "typescript")))
      for (width in listOf(240, 400)) {
        view.measure(
          View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
          View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        val pane = view.getChildAt(0) as HorizontalScrollView
        val label = view.getChildAt(1) as TextView
        val copy = view.getChildAt(2)
        // The divider is drawn halfway through the code pane's top padding.
        val dividerY = pane.top + pane.getChildAt(0).paddingTop / 2f
        val labelCenter = (label.top + label.bottom) / 2f
        val copyCenter = (copy.top + copy.bottom) / 2f
        assertEquals("Language label at size $size", dividerY / 2f, labelCenter, 1f)
        assertEquals("Copy control at size $size", dividerY / 2f, copyCenter, 1f)
      }
    }
  }
}

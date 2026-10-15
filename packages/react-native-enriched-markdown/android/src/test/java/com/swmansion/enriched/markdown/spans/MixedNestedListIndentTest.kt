package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.SpannableString
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.widget.TextView
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListTapUtils
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MixedNestedListIndentTest {
  private val context = RuntimeEnvironment.getApplication()

  @Test
  fun bulletsUnderNumbers() = assertMixedGap(Kind.ORDERED, Kind.BULLET)

  @Test
  fun numbersUnderBullets() = assertMixedGap(Kind.BULLET, Kind.ORDERED)

  @Test
  fun tasksUnderBullets() = assertMixedGap(Kind.BULLET, Kind.TASK)

  @Test
  fun tasksUnderNumbers() = assertMixedGap(Kind.ORDERED, Kind.TASK)

  @Test
  fun bulletsUnderTasks() = assertMixedGap(Kind.TASK, Kind.BULLET)

  @Test
  fun numbersUnderTasks() = assertMixedGap(Kind.TASK, Kind.ORDERED)

  @Test
  fun topLevelAndSameTypeNestsKeepBaseGeometry() {
    val config = styleConfig()
    val baseColumns = mapOf(Kind.ORDERED to 22f, Kind.BULLET to 3f, Kind.TASK to 14f)
    for ((kind, column) in baseColumns) {
      val markers = drawMarkers(config, list(kind, list(kind, list(kind))))
      assertEquals(listOf(0, 1, 2), markers.map { it.depth })
      markers.forEach {
        assertEquals("base text for $kind at depth ${it.depth}", column + 6f + it.depth * 24f, it.paragraphLeft, 0f)
        assertEquals(column + it.depth * 24f, it.marker.right, 0.01f)
      }
    }
  }

  @Test
  fun mixedColumnsUseAbsoluteIndentsWithoutFractionalDrift() {
    for (margin in listOf(24.0, 4.0)) {
      val config = styleConfig(bulletSize = 6.5, marginLeft = margin)
      val tree = list(Kind.BULLET, list(Kind.ORDERED, list(Kind.BULLET, list(Kind.TASK))))
      val columns = listOf(3.25f, 22f, 3.25f, 14f)
      drawMarkers(config, tree).forEach {
        val expected = (it.depth * margin + columns[it.depth] + 6f).toInt().toFloat()
        assertEquals("absolute indent at depth ${it.depth}, margin $margin", expected, it.paragraphLeft, 0f)
        assertEquals(it.paragraphLeft - 6f, it.marker.right, 0.99f)
      }
    }
  }

  @Test
  fun mixedAncestorsAndFollowingSiblingsRestoreTheirOwnColumns() {
    val config = styleConfig()
    val kinds = listOf(Kind.ORDERED, Kind.BULLET, Kind.TASK)
    for (parent in kinds) {
      val tree = list(parent).copy(children = kinds.map { child -> item(parent, list(child, list(parent))) })
      assertGaps(config, tree, list(Kind.BULLET), list(Kind.ORDERED), list(Kind.TASK))
    }
  }

  @Test
  fun wrappedLinesKeepTheChildsOwnColumn() {
    val config = styleConfig()
    val child = list(Kind.ORDERED)
    val paragraph = MarkdownASTNode(NodeType.Paragraph, children = listOf(MarkdownASTNode(NodeType.Text, "wrapped child text ".repeat(12))))
    val tree = list(Kind.BULLET, child.copy(children = listOf(child.children[0].copy(children = listOf(paragraph)))))
    val renderer = Renderer()
    renderer.configure(config, context)
    val text = SpannableString(renderer.renderContent(listOf(tree)))
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, TextPaint(), 180).build()
    val span = text.getSpans(0, text.length, OrderedListSpan::class.java).single()
    val firstLine = layout.getLineForOffset(text.getSpanStart(span))
    val lastLine = layout.getLineForOffset(text.getSpanEnd(span) - 1)
    assertTrue(lastLine > firstLine)
    for (line in firstLine..lastLine) {
      assertEquals(52, layout.getParagraphLeft(line))
    }
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    layout.draw(canvas)
    assertEquals(2, canvas.markers.size)
    assertEquals(46f, canvas.markers.last().right, 0.01f)
  }

  @Test
  fun togglingTaskUnderBulletKeepsEveryListMargin() = assertTaskToggleKeepsMargins(list(Kind.BULLET, list(Kind.TASK, list(Kind.ORDERED))))

  @Test
  fun togglingTaskUnderNumberKeepsEveryListMargin() = assertTaskToggleKeepsMargins(list(Kind.ORDERED, list(Kind.TASK)))

  private fun assertTaskToggleKeepsMargins(tree: MarkdownASTNode) {
    val config = styleConfig()
    val renderer = Renderer()
    renderer.configure(config, context)
    val textView = TextView(context)
    textView.setText(SpannableString(renderer.renderContent(listOf(tree))), TextView.BufferType.SPANNABLE)

    fun margins(): List<List<Int>> {
      val text = textView.text as Spanned
      return text
        .getSpans(0, text.length, BaseListSpan::class.java)
        .sortedWith(compareBy({ text.getSpanStart(it) }, { it.depth }, { text.getSpanEnd(it) }))
        .map { listOf(text.getSpanStart(it), text.getSpanEnd(it), it.depth, it.getLeadingMargin(true), it.getLeadingMargin(false)) }
    }

    val before = margins()
    assertTrue(before.isNotEmpty())
    for (checked in listOf(true, false)) {
      assertTrue(TaskListTapUtils.updateTaskListItemCheckedState(textView, 0, checked, config))
      val text = textView.text as Spanned
      assertTrue(text.getSpans(0, text.length, TaskListSpan::class.java).all { it.isChecked == checked })
      assertEquals("all list margins after checked=$checked", before, margins())
    }
  }

  @Test
  fun rtlMixedNestsKeepMarkerGapsAtBothDepths() {
    fun rtl(node: MarkdownASTNode): MarkdownASTNode {
      if (node.type == NodeType.Text) return node.copy(content = "\u05e4\u05e8\u05d9\u05d8")
      return node.copy(children = node.children.map { rtl(it) })
    }

    val config = styleConfig()
    for (parent in Kind.entries) {
      for (child in Kind.entries.filter { it != parent }) {
        val checkedStates = if (parent == Kind.TASK || child == Kind.TASK) listOf(false, true) else listOf(false)
        for (checked in checkedStates) {
          val tree = list(parent, list(child, list(parent, checked = checked), checked), checked)
          val markers = drawMarkers(config, rtl(tree))
          assertEquals(listOf(0, 1, 2), markers.map { it.depth })
          markers.forEach {
            assertEquals("RTL paragraph at depth ${it.depth}", -1, it.direction)
            assertEquals("$child under $parent, checked=$checked, depth ${it.depth}", it.paragraphRight + 6f, it.marker.left, 0.01f)
          }
        }
      }
    }
  }

  @Test
  fun equalMinimumColumnsKeepBaseGeometryForMixedNests() {
    val config = styleConfig(markerMinWidth = 40.0)
    for (parent in Kind.entries) {
      for (child in Kind.entries.filter { it != parent }) {
        val markers = drawMarkers(config, list(parent, list(child, list(parent))))
        assertEquals(listOf(0, 1, 2), markers.map { it.depth })
        markers.forEach {
          assertEquals("base text for $child under $parent at depth ${it.depth}", 46f + it.depth * 24f, it.paragraphLeft, 0f)
          assertEquals(40f + it.depth * 24f, it.marker.right, 0.01f)
        }
      }
    }
  }

  private fun assertMixedGap(
    parent: Kind,
    child: Kind,
  ) {
    val config = styleConfig()
    val checkedStates = if (parent == Kind.TASK || child == Kind.TASK) listOf(false, true) else listOf(false)
    for (checked in checkedStates) {
      val markers = drawMarkers(config, list(parent, list(child, checked = checked), checked))
      assertEquals(2, markers.size)
      assertEquals(1, markers.last().depth)
      markers.forEach {
        assertEquals("$child under $parent at depth ${it.depth}", it.paragraphLeft - 6f, it.marker.right, 0.01f)
      }
    }
  }

  private fun assertGaps(
    config: StyleConfig,
    vararg lists: MarkdownASTNode,
  ) {
    drawMarkers(config, *lists).forEach {
      assertEquals("marker at depth ${it.depth}", it.paragraphLeft - 6f, it.marker.right, 0.01f)
    }
  }

  private enum class Kind { ORDERED, BULLET, TASK }

  private fun list(
    kind: Kind,
    child: MarkdownASTNode? = null,
    checked: Boolean = false,
  ) = MarkdownASTNode(
    if (kind == Kind.ORDERED) NodeType.OrderedList else NodeType.UnorderedList,
    attributes = mapOf("start" to "1"),
    children = listOf(item(kind, child, checked)),
  )

  private fun item(
    kind: Kind,
    child: MarkdownASTNode? = null,
    checked: Boolean = false,
  ) = MarkdownASTNode(
    NodeType.ListItem,
    attributes = if (kind == Kind.TASK) mapOf("isTask" to "true", "taskChecked" to checked.toString()) else emptyMap(),
    children =
      listOf(
        MarkdownASTNode(NodeType.Paragraph, children = listOf(MarkdownASTNode(NodeType.Text, "item"))),
      ) + listOfNotNull(child),
  )

  private fun drawMarkers(
    config: StyleConfig,
    vararg lists: MarkdownASTNode,
  ): List<MarkerGeometry> {
    val renderer = Renderer()
    renderer.configure(config, context)
    // The view exposes spans in insertion order, as SpannableString does.
    val text = SpannableString(renderer.renderContent(lists.toList()))
    val paint = TextPaint().apply { textSize = config.listStyle.fontSize }
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, 2000).build()
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    layout.draw(canvas)
    assertEquals(text.getSpans(0, text.length, BaseListSpan::class.java).count { it.drawsMarker }, canvas.markers.size)
    return canvas.markers.map { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertTrue("marker left ${marker.left} on line $line", marker.left >= 0f)
      val start = layout.getLineStart(line)
      val depth = text.getSpans(start, start + 1, BaseListSpan::class.java).maxOf { it.depth }
      MarkerGeometry(
        marker,
        layout.getParagraphLeft(line).toFloat(),
        layout.getParagraphRight(line).toFloat(),
        layout.getParagraphDirection(line),
        depth,
      )
    }
  }

  private data class MarkerGeometry(
    val marker: DrawnMarker,
    val paragraphLeft: Float,
    val paragraphRight: Float,
    val direction: Int,
    val depth: Int,
  )

  private data class DrawnMarker(
    val left: Float,
    val right: Float,
    val baseline: Float,
  )

  private class MarkerCanvas(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val markers = mutableListOf<DrawnMarker>()

    override fun drawCircle(
      cx: Float,
      cy: Float,
      radius: Float,
      paint: Paint,
    ) {
      // Bullets are centered on the reserved column edge, matching the iOS drawer.
      markers += DrawnMarker(cx, cx, cy)
      super.drawCircle(cx, cy, radius, paint)
    }

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      val centerX = (left + right) / 2f
      markers += DrawnMarker(centerX, centerX, (top + bottom) / 2f)
      super.drawRect(left, top, right, bottom, paint)
    }

    override fun drawRoundRect(
      rect: android.graphics.RectF,
      rx: Float,
      ry: Float,
      paint: Paint,
    ) {
      val halfStroke = if (paint.style == Paint.Style.STROKE) paint.strokeWidth / 2f else 0f
      markers += DrawnMarker(rect.left - halfStroke, rect.right + halfStroke, rect.centerY())
      super.drawRoundRect(rect, rx, ry, paint)
    }

    override fun drawText(
      text: String,
      x: Float,
      y: Float,
      paint: Paint,
    ) {
      if (text.matches(Regex("(?:[0-9]+\\.|\\.[0-9]+)"))) markers += DrawnMarker(x, x + paint.measureText(text), y)
      super.drawText(text, x, y, paint)
    }
  }

  private fun styleConfig(
    markerMinWidth: Double = 0.0,
    bulletSize: Double = 6.0,
    marginLeft: Double = 24.0,
  ): StyleConfig {
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

    fun element() =
      JavaOnlyMap.of(
        "fontFamily",
        "",
        "fontWeight",
        "normal",
        "fontSize",
        16.0,
        "lineHeight",
        0.0,
        "marginTop",
        0.0,
        "marginBottom",
        0.0,
        "color",
        Color.BLACK,
        "backgroundColor",
        Color.TRANSPARENT,
        "borderColor",
        Color.TRANSPARENT,
        "underline",
        false,
        "fontScale",
        0.8,
        "baselineOffsetScale",
        0.5,
      )

    val style = JavaOnlyMap()
    listOf("paragraph", "strong", "em", "strikethrough", "code", "superscript", "subscript", "highlight", "link")
      .forEach { style.putMap(it, element()) }
    style.putMap(
      "spoiler",
      element().apply {
        putMap("particles", JavaOnlyMap.of("density", 0.5, "speed", 1.0))
        putMap("solid", JavaOnlyMap.of("borderRadius", 0.0))
      },
    )
    style.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        Color.BLACK,
        "borderColor",
        Color.BLACK,
        "checkmarkColor",
        Color.BLACK,
        "checkedTextColor",
        Color.BLACK,
        "checkboxSize",
        14.0,
        "checkboxBorderRadius",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    style.putMap(
      "list",
      element().apply {
        putInt("bulletColor", Color.BLACK)
        putInt("markerColor", Color.BLACK)
        putDouble("bulletSize", bulletSize)
        putDouble("markerMinWidth", markerMinWidth)
        putDouble("gapWidth", 6.0)
        putDouble("marginLeft", marginLeft)
        putDouble("itemSpacing", 0.0)
      },
    )
    return StyleConfig(style, context, false, 0f)
  }
}

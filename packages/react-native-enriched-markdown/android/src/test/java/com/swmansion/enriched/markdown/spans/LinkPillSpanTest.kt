package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Looper
import android.os.SystemClock
import android.text.SpanWatcher
import android.text.Spannable
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Base64
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.LinkRenderer
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.renderer.RendererConfig
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentHeightMeasurer
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.styles.LinkPillContent
import com.swmansion.enriched.markdown.styles.LinkPillStyle
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleParser
import com.swmansion.enriched.markdown.utils.common.parseLinkPillContent
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
import com.swmansion.enriched.markdown.utils.text.LocalImageLoader
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LinkPillSpanTest {
  private val original = "Original Markdown label"
  private val style =
    LinkVariantEntry("^https:", Color.BLUE, false, Color.LTGRAY, pill = LinkPillStyle(label = "Visual", borderWidth = 1f))

  /** [style] with its nested pill changed. */
  private fun pillStyle(change: LinkPillStyle.() -> LinkPillStyle) = style.copy(pill = style.pill!!.change())

  @Before
  fun isolateIconCache() {
    // Never touch the network, and drive cache revalidation from the tests.
    LinkPillIconCache.remoteLoader = { _, _, _, _ -> }
    LinkPillIconCache.clock = { now }
    now += 60_000
  }

  @After
  fun restoreIconCache() {
    LinkPillIconCache.remoteLoader = ImageDownloader::download
    LinkPillIconCache.clock = SystemClock::uptimeMillis
  }

  private val paint =
    TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      textSize = 16f
      typeface = Typeface.DEFAULT
    }

  private fun span(variant: LinkVariantEntry = style) =
    LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, RuntimeEnvironment.getApplication())

  private fun writeIcon(
    file: File,
    color: Int = Color.RED,
  ) {
    val bitmap = Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888)
    bitmap.eraseColor(color)
    for (y in 0 until 16) {
      for (x in 8 until 16) bitmap.setPixel(x, y, Color.GREEN)
      for (x in 0 until 16) bitmap.setPixel(x, 0, Color.TRANSPARENT)
      for (x in 0 until 16) {
        if (y in 4..6) bitmap.setPixel(x, y, Color.TRANSPARENT)
        if (y in 11..13) bitmap.setPixel(x, y, Color.argb(128, 255, 0, 0))
      }
    }
    file.outputStream().use { assertTrue("PNG encoding", bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
    assertTrue("PNG bytes", file.length() > 0)
  }

  @Test
  fun iconCacheInvalidatesModifiedFilesAndBoundsEntryCountWithoutRecyclingOwners() {
    val files = mutableListOf<File>()
    try {
      val file = File.createTempFile("enriched-cache", ".png").also { files.add(it) }
      writeIcon(file)
      val uri = file.toURI().toString()
      val first = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
      assertSame(first, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      val modified = file.lastModified()
      writeIcon(file, Color.BLUE)
      assertTrue(file.setLastModified(modified + 2000))
      // Within the revalidation window the file is not stat'ed again.
      assertSame(first, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      now += 2_000
      val updated = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
      assertNotSame(first, updated)
      assertEquals(Color.BLUE, updated.getPixel(2, 8))
      repeat(64) {
        val next = File.createTempFile("enriched-cache", ".png").also { files.add(it) }
        writeIcon(next)
        LinkPillIconCache.load(RuntimeEnvironment.getApplication(), next.toURI().toString())
      }
      assertNotSame(updated, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      assertFalse(updated.isRecycled)
      assertEquals(Color.RED, first.getPixel(2, 8))
    } finally {
      files.forEach { it.delete() }
    }
  }

  @Test
  fun iconCacheBoundsPixelMemoryAndSamplesOversizedIcons() {
    val files = mutableListOf<File>()
    try {
      var first: Bitmap? = null
      repeat(9) {
        val file = File.createTempFile("enriched-large-icon", ".png").also { files.add(it) }
        val source = Bitmap.createBitmap(1024, 1024, Bitmap.Config.ARGB_8888)
        source.eraseColor(Color.RED)
        file.outputStream().use { assertTrue(source.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        source.recycle()
        val decoded = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), file.toURI().toString())!!
        assertTrue(decoded.width <= 512 && decoded.height <= 512)
        if (it == 0) first = decoded
      }
      assertNotSame(first, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), files.first().toURI().toString()))
      assertFalse(first!!.isRecycled)
    } finally {
      files.forEach { it.delete() }
    }
  }

  @Test
  fun preservesOriginalCharactersAndAccessibilityLabel() {
    val pill = span()
    val text = SpannableString(original)
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertEquals(original, text.toString())
    assertEquals("Visual, $original", pill.contentDescription)
    assertFalse(text.toString().contains('\uFFFC'))
  }

  @Test
  fun accessibleLinkNodeIncludesVisibleAndOriginalText() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val text = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com/original"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, text, null, null, factory)
    factory.flushDeferredSpans(text)
    val view = TextView(context)
    view.text = text
    view.measure(
      View.MeasureSpec.makeMeasureSpec(300, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.EXACTLY),
    )
    view.layout(0, 0, 300, 100)
    val helper = MarkdownAccessibilityHelper(view)
    helper.invalidateAccessibilityItems()
    val accessible = helper.getAccessibilityNodeProvider(view)!!.createAccessibilityNodeInfo(0)!!
    assertEquals("Visual label, $original", accessible.text.toString())
    assertEquals(original, view.text.toString())
    assertEquals(original, span(pillStyle { copy(label = "") }).accessibilityText)
    assertEquals(original, span(pillStyle { copy(label = original) }).accessibilityText)
    helper.cleanup()
  }

  @Test
  fun localDataIconsDownsampleBothAxesWithoutChangingOrdinaryImagePolicy() {
    val source = Bitmap.createBitmap(32, 2048, Bitmap.Config.ARGB_8888)
    source.eraseColor(Color.RED)
    val bytes = java.io.ByteArrayOutputStream()
    assertTrue(source.compress(Bitmap.CompressFormat.PNG, 100, bytes))
    source.recycle()
    val uri = "data:image/png;base64," + Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP)
    val decoded = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
    assertTrue(decoded.width <= 512 && decoded.height <= 512)
    assertEquals(Color.RED, decoded.getPixel(0, 0))
    val ordinaryImage = LocalImageLoader.load(RuntimeEnvironment.getApplication(), uri)!!
    assertEquals(2048, ordinaryImage.height)
    assertSame(decoded, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
  }

  @Test
  fun measuresPresentationLabelAndClampsToAvailableAndExplicitWidth() {
    val pill = span(pillStyle { copy(label = "A very long presentation label", maxWidth = 100f) })
    pill.prepareForMeasurement(200)
    assertEquals(100, pill.getSize(paint, original, 0, original.length, null))
    pill.prepareForMeasurement(60)
    assertEquals(60, pill.getSize(paint, original, 0, original.length, null))
  }

  @Test
  fun shortVisualLabelHasLessWidthThanOriginalFallback() {
    val short = span(pillStyle { copy(label = "X") })
    val fallback = span(pillStyle { copy(label = "") })
    assertTrue(short.getSize(paint, original, 0, original.length, null) < fallback.getSize(paint, original, 0, original.length, null))
  }

  @Test
  fun paddingAndBorderExpandFontMetricsWithoutMutatingPaint() {
    val pill = span(pillStyle { copy(paddingVertical = 8f, borderWidth = 2f) })
    val metrics = paint.fontMetricsInt
    val before = paint.fontMetricsInt
    pill.getSize(paint, original, 0, original.length, metrics)
    assertTrue(metrics.ascent <= before.ascent - 10)
    assertTrue(metrics.descent >= before.descent + 10)
    assertEquals(16f, paint.textSize, 0f)
    assertEquals(Typeface.DEFAULT, paint.typeface)
  }

  @Test
  fun layoutWrapsWholePillAndRetainsOriginalSelectionText() {
    val text = SpannableString("before $original after")
    val start = "before ".length
    val pill = span(pillStyle { copy(label = "A long visual label", maxWidth = 80f) })
    text.setSpan(pill, start, start + original.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 90)
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, 90)
        .setIncludePad(false)
        .build()
    assertTrue(layout.lineCount > 1)
    for (line in 0 until layout.lineCount - 1) {
      val end = layout.getLineEnd(line)
      assertFalse("Pill was split at $end", end > start && end < start + original.length)
    }
    assertEquals(original, text.subSequence(start, start + original.length).toString())
  }

  @Test
  fun invalidOrPendingIconFallsBackWithoutExceptions() {
    for (uri in listOf("file:///does-not-exist.png", "https://example.com/pending.png", "")) {
      val pill = span(pillStyle { copy(iconUri = uri) })
      pill.prepareForMeasurement(30)
      assertEquals(30, pill.getSize(paint, original, 0, original.length, null))
      pill.draw(Canvas(), original, 0, original.length, 0f, 0, 20, 40, paint)
    }
  }

  @Test
  fun rendererKeepsOriginalLinkCallbacksAndMarkdownExtractionWithPresentationLabel() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val url = "https://example.com/original"
    val presses = mutableListOf<String>()
    val longPresses = mutableListOf<String>()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to url),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, { presses.add(it) }, { longPresses.add(it) }, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(original, builder.toString())
    assertEquals(1, builder.getSpans(0, builder.length, LinkPillSpan::class.java).size)
    assertEquals("[$original]($url)", MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
    val link = builder.getSpans(0, builder.length, LinkSpan::class.java).single()
    val view = TextView(context)
    link.onClick(view)
    link.onLongClick(view)
    link.onClick(view)
    assertEquals(listOf(url), presses)
    assertEquals(listOf(url), longPresses)
  }

  @Test
  fun pillInheritsTheSameBlockFontWeightAndSizeAsTheOrdinaryLink() {
    val context = RuntimeEnvironment.getApplication()
    val label = "MMMMWW"
    val config = testStyleConfig(true, presentationLabel = label)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle.copy(fontWeight = "bold", fontSize = 24f))
    val builder = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    val ordinaryPaint = TextPaint(paint)
    builder.getSpans(0, builder.length, LinkSpan::class.java).single().updateDrawState(ordinaryPaint)
    assertTrue(ordinaryPaint.typeface.isBold)
    assertEquals(24f, ordinaryPaint.textSize, 0f)
    val pill = builder.getSpans(0, builder.length, LinkPillSpan::class.java).single()
    pill.prepareForMeasurement(1000)
    assertEquals(
      kotlin.math.ceil(ordinaryPaint.measureText(label) + 12f).toInt(),
      pill.getSize(paint, builder, 0, builder.length, null),
    )
  }

  @Test
  fun existingNonPillVariantsKeepOrdinaryLinks() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(false)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(original, builder.toString())
    assertTrue(builder.getSpans(0, builder.length, LinkPillSpan::class.java).isEmpty())
    assertEquals(1, builder.getSpans(0, builder.length, LinkSpan::class.java).size)
  }

  @Test
  fun inlineCodePillSuppressesOpaqueCodeBackgroundAndPreservesExtraction() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true, Color.RED, "file.ts")
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val path = "src/a/really/long/original/document/file.ts"
    val url = "https://example.com/file"
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to url),
        children =
          listOf(
            MarkdownASTNode(
              MarkdownASTNode.NodeType.Code,
              children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, path)),
            ),
          ),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(path, builder.toString())
    val code = builder.getSpans(0, builder.length, CodeSpan::class.java).single()
    val background = builder.getSpans(0, builder.length, CodeBackgroundSpan::class.java).single()
    val pill = builder.getSpans(0, builder.length, LinkPillSpan::class.java).single()
    LinkPillSpan.prepareForMeasurement(builder, 240)
    val originalMarkdown = MarkdownExtractor.extractFromSpannable(builder, 0, builder.length)
    assertEquals("[$path]($url)", originalMarkdown)

    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, builder, 0, builder.length, 0)
    assertTrue("Covered code background must not paint outside rounded pill", pixels(bitmap).all { it == Color.TRANSPARENT })
    assertEquals(0, builder.getSpanStart(code))
    assertEquals(path.length, builder.getSpanEnd(code))

    // Removing only presentation must leave the same Markdown and restore ordinary code painting.
    builder.removeSpan(pill)
    assertEquals(originalMarkdown, MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, builder, 0, builder.length, 0)
    assertTrue("Ordinary inline code still paints its configured background", pixels(bitmap).any { it == Color.RED })

    // Recognition's synthetic-link suppression can still recover the original inline-code mark.
    builder.removeSpan(builder.getSpans(0, builder.length, LinkSpan::class.java).single())
    assertEquals("`$path`", MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
  }

  @Test
  fun partialPillCoverageKeepsCodeBackgroundOnBothSides() {
    val config = testStyleConfig(true, Color.RED)
    val text = SpannableString("left original long path right")
    val start = "left ".length
    val end = text.length - " right".length
    val background = CodeBackgroundSpan(config)
    val pill =
      LinkPillSpan(
        pillStyle { copy(label = "X") },
        Typeface.DEFAULT,
        16f,
        text.subSequence(start, end).toString(),
        RuntimeEnvironment.getApplication(),
      )
    text.setSpan(background, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 240)
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, 240)
        .setIncludePad(false)
        .build()
    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    val coveredLeft = layout.getPrimaryHorizontal(start)
    val coveredRight = layout.getPrimaryHorizontal(end)
    assertEquals(Color.TRANSPARENT, bitmap.getPixel(((coveredLeft + coveredRight) / 2).toInt(), 20))
    assertEquals(Color.RED, bitmap.getPixel((coveredLeft / 2).toInt(), 20))
    assertEquals(Color.RED, bitmap.getPixel(((coveredRight + layout.getLineWidth(0)) / 2).toInt(), 20))
  }

  @Test
  fun concealedSpoilerKeepsPartialPillCodeBackgroundHiddenUntilReveal() {
    val config = testStyleConfig(true, Color.RED)
    val originalText = "left original source path right"
    val text = SpannableString(originalText)
    val start = "left ".length
    val end = text.length - " right".length
    val background = CodeBackgroundSpan(config)
    val spoiler = SpoilerSpan(SpanStyleCache(config), BlockStyle(16f, "", "normal", Color.BLACK))
    val pill =
      LinkPillSpan(
        pillStyle { copy(label = "X") },
        Typeface.DEFAULT,
        16f,
        text.subSequence(start, end).toString(),
        RuntimeEnvironment.getApplication(),
      )
    text.setSpan(background, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(spoiler, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 240)
    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    assertTrue("Concealed code background must remain hidden around a pill", pixels(bitmap).all { it == Color.TRANSPARENT })

    spoiler.markRevealing()
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    assertTrue("Code background outside the pill returns when reveal starts", pixels(bitmap).any { it == Color.RED })
    assertEquals(originalText, text.toString())
    assertSame(background, text.getSpans(0, text.length, CodeBackgroundSpan::class.java).single())
    assertEquals(0, text.getSpanStart(background))
    assertEquals(text.length, text.getSpanEnd(background))
  }

  private fun pixels(bitmap: Bitmap): IntArray =
    IntArray(bitmap.width * bitmap.height).also {
      bitmap.getPixels(it, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
    }

  private fun testStyleConfig(
    pill: Boolean,
    codeBackground: Int = Color.TRANSPARENT,
    presentationLabel: String = "Visual label",
    blockquotePadding: Double = 0.0,
  ): StyleConfig {
    val context = RuntimeEnvironment.getApplication()
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

    fun inlineStyle() =
      JavaOnlyMap.of(
        "fontSize",
        16.0,
        "fontFamily",
        "",
        "fontWeight",
        "normal",
        "color",
        Color.BLACK.toDouble(),
        "marginTop",
        0.0,
        "marginBottom",
        0.0,
        "lineHeight",
        20.0,
        "underline",
        false,
        "backgroundColor",
        0.0,
        "borderColor",
        0.0,
      )
    val map = JavaOnlyMap()
    for (name in listOf("paragraph", "link", "strong", "em", "strikethrough", "code", "highlight")) {
      map.putMap(name, inlineStyle())
    }
    map.putMap(
      "code",
      inlineStyle().apply {
        putDouble("backgroundColor", codeBackground.toDouble())
        putDouble("borderColor", codeBackground.toDouble())
      },
    )
    for (name in listOf("superscript", "subscript")) {
      map.putMap(name, JavaOnlyMap.of("fontScale", 0.7, "baselineOffsetScale", 0.3))
    }
    map.putMap(
      "spoiler",
      JavaOnlyMap.of(
        "color",
        Color.GRAY.toDouble(),
        "particles",
        JavaOnlyMap.of("density", 1.0, "speed", 0.0),
        "solid",
        JavaOnlyMap.of("borderRadius", 4.0),
      ),
    )
    map.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        0.0,
        "borderColor",
        0.0,
        "checkboxSize",
        16.0,
        "checkboxBorderRadius",
        4.0,
        "checkmarkColor",
        0.0,
        "checkedTextColor",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    map.putArray(
      "linkVariants",
      JavaOnlyArray.of(
        JavaOnlyMap.of(
          "pattern",
          "^https:",
          "color",
          Color.BLUE.toDouble(),
          "underline",
          false,
          "backgroundColor",
          Color.LTGRAY.toDouble(),
          "pill",
          JavaOnlyMap.of("enabled", pill, "label", presentationLabel),
        ),
      ),
    )
    map.putMap(
      "blockquote",
      inlineStyle().apply {
        putDouble("borderWidth", 3.0)
        putDouble("gapWidth", 16.0)
        putDouble("borderRadius", 0.0)
        putDouble("padding", blockquotePadding)
      },
    )
    return StyleConfig(map, context, false, 0f)
  }

  @Test
  fun nestedBlockMarginsReduceAvailablePillWidth() {
    val text = SpannableString(original)
    val pill = span(pillStyle { copy(label = "A very long presentation label") })
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(
      android.text.style.LeadingMarginSpan
        .Standard(25),
      0,
      text.length,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    LinkPillSpan.prepareForMeasurement(text, 60)
    assertEquals(35, pill.getSize(paint, text, 0, text.length, null))
  }

  @Test
  fun widthChangesAreReportedForVisibleLayoutInvalidation() {
    val text = SpannableString(original)
    text.setSpan(span(), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertTrue(LinkPillSpan.prepareForMeasurement(text, 40))
    assertFalse(LinkPillSpan.prepareForMeasurement(text, 40))
    assertTrue(LinkPillSpan.prepareForMeasurement(text, 80))
  }

  private fun textNode(value: String) = MarkdownASTNode(MarkdownASTNode.NodeType.Text, value)

  private fun linkNode(
    url: String,
    vararg children: MarkdownASTNode,
  ) = MarkdownASTNode(MarkdownASTNode.NodeType.Link, attributes = mapOf("url" to url), children = children.toList())

  private fun paragraphNode(vararg children: MarkdownASTNode) =
    MarkdownASTNode(MarkdownASTNode.NodeType.Paragraph, children = children.toList())

  /** The production entry point, as the views and the measurement store use it. */
  private fun renderDocument(
    config: StyleConfig,
    vararg blocks: MarkdownASTNode,
  ) = Renderer().run {
    configure(config, RuntimeEnvironment.getApplication())
    renderDocument(MarkdownASTNode(MarkdownASTNode.NodeType.Document, children = blocks.toList()))
  }

  private fun pillsIn(text: Spanned) = text.getSpans(0, text.length, LinkPillSpan::class.java).sortedBy { text.getSpanStart(it) }

  @Test
  fun perLinkContentWinsOverTheVariantWhichWinsOverTheLinkText() {
    val config = testStyleConfig(true, presentationLabel = "Variant label")
    val first = "https://example.com/first"
    val second = "https://example.com/second"
    config.linkPillContent = mapOf(first to LinkPillContent(label = "Per link"), second to LinkPillContent())
    val rendered =
      renderDocument(
        config,
        paragraphNode(
          linkNode(first, textNode(original)),
          textNode(" "),
          linkNode(second, textNode(original)),
          textNode(" "),
          linkNode("https://example.com/third", textNode(original)),
        ),
      )
    assertEquals(
      listOf("Per link, $original", "Variant label, $original", "Variant label, $original"),
      pillsIn(rendered).map { it.accessibilityText },
    )
    assertEquals("$original $original $original", rendered.toString())

    // No variant label either: the link text itself is shown.
    val unlabeled = testStyleConfig(true, presentationLabel = "")
    val fallback = renderDocument(unlabeled, paragraphNode(linkNode(first, textNode(original))))
    assertEquals(original, pillsIn(fallback).single().accessibilityText)

    // Content never turns an ordinary link into a pill; presentation is the variant's call.
    val ordinary = testStyleConfig(false)
    ordinary.linkPillContent = mapOf(first to LinkPillContent(label = "Per link"))
    assertTrue(pillsIn(renderDocument(ordinary, paragraphNode(linkNode(first, textNode(original))))).isEmpty())
  }

  @Test
  fun perLinkIconWinsOverTheVariantIcon() {
    val file = File.createTempFile("enriched-content-icon", ".png")
    try {
      writeIcon(file)
      val withoutIcon = span(pillStyle { copy(label = "X") })
      val withIcon =
        LinkPillSpan(
          pillStyle { copy(label = "X") },
          Typeface.DEFAULT,
          16f,
          original,
          RuntimeEnvironment.getApplication(),
          LinkPillContent(iconUri = file.toURI().toString()),
        )
      // The icon slot is the font size plus a quarter of it.
      assertEquals(
        withoutIcon.getSize(paint, original, 0, original.length, null) + 20,
        withIcon.getSize(paint, original, 0, original.length, null),
      )
    } finally {
      file.delete()
    }
  }

  @Test
  fun linkPillContentPropParsesIntoAUrlKeyedMap() {
    val parsed =
      parseLinkPillContent(
        JavaOnlyArray.of(
          JavaOnlyMap.of("url", "https://example.com/a", "label", "A", "iconUri", ""),
          JavaOnlyMap.of("url", "https://example.com/b", "label", "", "iconUri", "pill_file"),
        ),
      )
    assertEquals(
      mapOf(
        "https://example.com/a" to LinkPillContent("A", ""),
        "https://example.com/b" to LinkPillContent("", "pill_file"),
      ),
      parsed,
    )
    assertTrue(parseLinkPillContent(null).isEmpty())
  }

  @Test
  fun remoteIconReservesItsSlotAndRedrawsRegisteredViewsWhenItArrives() {
    val context = RuntimeEnvironment.getApplication()
    val callbacks = mutableListOf<(Bitmap?) -> Unit>()
    var requestedHeaders: Map<String, String>? = null
    LinkPillIconCache.remoteLoader = { _, _, headers, callback ->
      requestedHeaders = headers
      callbacks.add(callback)
    }
    val url = "https://example.com/icon-${System.nanoTime()}.png"
    val headers = mapOf("Authorization" to "token")
    val variant = pillStyle { copy(label = "X", iconUri = url) }

    val plain = span(pillStyle { copy(label = "X") })
    val remote = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context, null, headers)
    assertEquals(headers, requestedHeaders)
    val reserved = remote.getSize(paint, original, 0, original.length, null)
    assertEquals(plain.getSize(paint, original, 0, original.length, null) + 20, reserved)

    var invalidations = 0
    val view =
      object : View(context) {
        override fun postInvalidate() {
          invalidations++
        }
      }
    remote.registerView(view)
    val bitmap = Bitmap.createBitmap(reserved, 40, Bitmap.Config.ARGB_8888)
    remote.draw(Canvas(bitmap), original, 0, original.length, 0f, 0, 24, 40, paint)
    assertFalse("No icon before it loads", pixels(bitmap).any { it == Color.RED })

    val downloaded = Bitmap.createBitmap(1024, 512, Bitmap.Config.ARGB_8888)
    downloaded.eraseColor(Color.RED)
    callbacks.single()(downloaded)
    assertEquals(1, invalidations)
    assertEquals("Arrival needs a redraw, not a relayout", reserved, remote.getSize(paint, original, 0, original.length, null))
    remote.draw(Canvas(bitmap), original, 0, original.length, 0f, 0, 24, 40, paint)
    assertTrue("Loaded icon is drawn", pixels(bitmap).any { it == Color.RED })

    // The next render is served from the bounded thumbnail cache without a request.
    LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context, null, headers)
    assertEquals(1, callbacks.size)
    val cached = LinkPillIconCache.loadRemote(context, url, headers) {}!!
    assertTrue(cached.width <= 256 && cached.height <= 256)
  }

  @Test
  fun failedRemoteIconKeepsItsSlotAndIsNotRequestedOnEveryRender() {
    val context = RuntimeEnvironment.getApplication()
    val callbacks = mutableListOf<(Bitmap?) -> Unit>()
    LinkPillIconCache.remoteLoader = { _, _, _, callback -> callbacks.add(callback) }
    val variant = pillStyle { copy(label = "X", iconUri = "https://example.com/missing-${System.nanoTime()}.png") }
    val pill = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
    val reserved = pill.getSize(paint, original, 0, original.length, null)
    callbacks.single()(null)
    assertEquals(reserved, pill.getSize(paint, original, 0, original.length, null))
    pill.draw(Canvas(), original, 0, original.length, 0f, 0, 20, 40, paint)

    val next = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
    assertEquals("A failed download is not retried within the retry window", 1, callbacks.size)
    assertTrue("The next render holds no slot for it", next.getSize(paint, original, 0, original.length, null) < reserved)
    now += 60_000
    LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
    assertEquals(2, callbacks.size)
  }

  /** Selectable text is drawn from a cached display list; only a span change records it again. */
  private fun spanChangesIn(view: TextView): List<Any> {
    val changed = mutableListOf<Any>()
    val text = view.text as Spannable
    text.setSpan(
      object : SpanWatcher {
        override fun onSpanAdded(
          text: Spannable,
          what: Any,
          start: Int,
          end: Int,
        ) = Unit

        override fun onSpanRemoved(
          text: Spannable,
          what: Any,
          start: Int,
          end: Int,
        ) = Unit

        override fun onSpanChanged(
          text: Spannable,
          what: Any,
          oldStart: Int,
          oldEnd: Int,
          newStart: Int,
          newEnd: Int,
        ) {
          changed.add(what)
        }
      },
      0,
      text.length,
      Spanned.SPAN_INCLUSIVE_INCLUSIVE,
    )
    return changed
  }

  @Test
  fun iconArrivingAfterTheFirstDrawChangesThePillSpanOnItsTextView() {
    val context = RuntimeEnvironment.getApplication()
    val callbacks = mutableListOf<(Bitmap?) -> Unit>()
    LinkPillIconCache.remoteLoader = { _, _, _, callback -> callbacks.add(callback) }
    val variant = pillStyle { copy(label = "X", iconUri = "https://example.com/late-${System.nanoTime()}.png") }
    val pill = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
    val text = SpannableString(original)
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val view = object : AccessibleMarkdownTextView(context) {}
    view.layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.setText(text, TextView.BufferType.SPANNABLE)
    val changed = spanChangesIn(view)

    callbacks.single()(Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888))
    assertTrue(changed.any { it === pill })
  }

  @Test
  fun spoilerRevealChangesTheSpansOfThePillsItConcealed() {
    val context = RuntimeEnvironment.getApplication()
    val text = SpannableString("before $original after")
    val start = "before ".length
    val end = start + original.length
    val spoiler = SpoilerSpan(SpanStyleCache(testStyleConfig(true)), BlockStyle(16f, "", "normal", Color.BLACK))
    text.setSpan(spoiler, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val pill = span(style)
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val outside = span(style)
    text.setSpan(outside, 0, start - 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val view = object : AccessibleMarkdownTextView(context) {}
    view.layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.setText(text, TextView.BufferType.SPANNABLE)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(400, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, 400, view.measuredHeight)
    val changed = spanChangesIn(view)

    SpoilerOverlayDrawer(view).revealSpan(spoiler) {}
    assertTrue(changed.any { it === pill })
    assertFalse(changed.any { it === outside })
  }

  @Test
  fun pillInsidePaddedBlockquoteCoversExactlyTheLink() {
    val url = "https://example.com/doc"
    for (padding in listOf(0.0, 8.0)) {
      val config = testStyleConfig(true, blockquotePadding = padding)
      for (leading in listOf("see ", "")) {
        val link = linkNode(url, textNode("Doc"))
        val children = if (leading.isEmpty()) arrayOf(link, textNode(" end")) else arrayOf(textNode(leading), link, textNode(" end"))
        val quote = MarkdownASTNode(MarkdownASTNode.NodeType.Blockquote, children = listOf(paragraphNode(*children)))
        val rendered = renderDocument(config, quote)
        val linkSpan = rendered.getSpans(0, rendered.length, LinkSpan::class.java).single()
        val pill = pillsIn(rendered).single()
        val case = "padding=$padding leading='$leading'"
        assertEquals(case, rendered.getSpanStart(linkSpan), rendered.getSpanStart(pill))
        assertEquals(case, rendered.getSpanEnd(linkSpan), rendered.getSpanEnd(pill))
        assertEquals(case, "Doc", rendered.substring(rendered.getSpanStart(pill), rendered.getSpanEnd(pill)))
      }
    }
  }

  @Test
  fun concealedSpoilerHidesThePillUntilRevealStarts() {
    val config = testStyleConfig(true)
    val text = SpannableString("before $original after")
    val start = "before ".length
    val end = start + original.length
    val spoiler = SpoilerSpan(SpanStyleCache(config), BlockStyle(16f, "", "normal", Color.BLACK))
    text.setSpan(spoiler, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val pill = span(pillStyle { copy(paddingVertical = 6f, borderWidth = 2f, borderColor = Color.RED) })
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 400)
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, 400)
        .setIncludePad(false)
        .build()
    val bitmap = Bitmap.createBitmap(400, layout.height, Bitmap.Config.ARGB_8888)
    layout.draw(Canvas(bitmap))
    assertFalse(
      "A concealed pill must not paint its background or border around the spoiler overlay",
      pixels(bitmap).any { it == Color.LTGRAY || it == Color.RED },
    )

    spoiler.markRevealing()
    layout.draw(Canvas(bitmap))
    assertTrue("The pill returns when the reveal starts", pixels(bitmap).any { it == Color.LTGRAY })
    assertEquals("before $original after", text.toString())
  }

  @Test
  fun linkContainingALineBreakStaysAnOrdinaryLink() {
    val config = testStyleConfig(true)
    val url = "https://example.com/doc"
    val broken =
      renderDocument(
        config,
        paragraphNode(
          textNode("before "),
          linkNode(url, textNode("one"), MarkdownASTNode(MarkdownASTNode.NodeType.LineBreak), textNode("two")),
          textNode(" after"),
        ),
      )
    assertTrue(pillsIn(broken).isEmpty())
    assertEquals(1, broken.getSpans(0, broken.length, LinkSpan::class.java).size)
    assertTrue(broken.toString().contains("one\ntwo"))

    // A soft break is a space, so the link is still one unbroken run.
    val soft =
      renderDocument(
        config,
        paragraphNode(linkNode(url, textNode("one"), MarkdownASTNode(MarkdownASTNode.NodeType.SoftBreak), textNode("two"))),
      )
    assertEquals(1, pillsIn(soft).size)
  }

  @Test
  fun linkContainingASpoilerStaysAnOrdinaryLink() {
    val config = testStyleConfig(true)
    val url = "https://example.com/doc"
    val spoiler = MarkdownASTNode(MarkdownASTNode.NodeType.Spoiler, children = listOf(textNode("secret")))
    val partlyHidden = renderDocument(config, paragraphNode(linkNode(url, textNode("see "), spoiler)))
    assertTrue("The label would show the hidden text", pillsIn(partlyHidden).isEmpty())
    assertEquals(1, partlyHidden.getSpans(0, partlyHidden.length, LinkSpan::class.java).size)

    // A link wholly inside a spoiler is still a pill; it is not drawn while concealed.
    val hidden =
      renderDocument(
        config,
        paragraphNode(MarkdownASTNode(MarkdownASTNode.NodeType.Spoiler, children = listOf(linkNode(url, textNode("secret"))))),
      )
    assertEquals(1, pillsIn(hidden).size)
  }

  @Test
  fun malformedRemoteIconSourceLeavesThePillWithoutAnIcon() {
    val context = RuntimeEnvironment.getApplication()
    LinkPillIconCache.remoteLoader = ImageDownloader::download
    val plain = span(pillStyle { copy(label = "X") }).getSize(paint, original, 0, original.length, null)
    for (source in listOf("https://exa mple.com/${System.nanoTime()}.png", "https://")) {
      val variant = pillStyle { copy(label = "X", iconUri = source) }
      LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
      // Reported like a failed download, so the next render holds no slot for it.
      shadowOf(Looper.getMainLooper()).idle()
      val next = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context)
      assertEquals(plain, next.getSize(paint, original, 0, original.length, null))
    }
  }

  @Test
  fun spansWaitingForTheSameDownloadShareOneThumbnail() {
    val context = RuntimeEnvironment.getApplication()
    val callbacks = mutableListOf<(Bitmap?) -> Unit>()
    LinkPillIconCache.remoteLoader = { _, _, _, callback -> callbacks.add(callback) }
    val url = "https://example.com/shared-${System.nanoTime()}.png"
    val received = mutableListOf<Bitmap>()
    repeat(2) { assertNull(LinkPillIconCache.loadRemote(context, url, emptyMap()) { received.add(it) }) }

    val downloaded = Bitmap.createBitmap(1024, 512, Bitmap.Config.ARGB_8888)
    callbacks.forEach { it(downloaded) }
    assertEquals(2, received.size)
    assertSame(received[0], received[1])
  }

  @Test
  fun segmentHeightMeasurerMatchesAPrimedLayoutWhenALongPillIsFollowedByText() {
    val context = RuntimeEnvironment.getApplication()
    val url = "https://example.com/doc"
    val longLabel = "a very long link label that certainly exceeds the width"
    val width = 120
    val cases =
      listOf(
        arrayOf(linkNode(url, textNode(longLabel)), textNode(" xyz")),
        arrayOf(textNode("some words before "), linkNode(url, textNode(longLabel)), textNode(" and some words after")),
      )
    for (children in cases) {
      val config = testStyleConfig(true, presentationLabel = "")
      // Fresh spans, exactly what the measurer receives from a render.
      val fresh = renderDocument(config, paragraphNode(*children))
      val measured =
        SegmentHeightMeasurer.measureSegmentsHeight(
          listOf(RenderedSegment.Text(fresh, emptyList(), false, 0f, 1L)),
          config,
          context,
          width.toFloat(),
          16f,
          0,
          false,
        ) { 0f }
      val shown = renderDocument(config, paragraphNode(*children))
      LinkPillSpan.prepareForMeasurement(shown, width)
      val layout =
        StaticLayout.Builder
          .obtain(shown, 0, shown.length, paint, width)
          .setIncludePad(false)
          .build()
      assertEquals(layout.height.toFloat(), measured, 0f)
      assertEquals(width, pillsIn(fresh).single().getSize(paint, fresh, 0, fresh.length, null))
    }
  }

  @Test
  fun visibleTextViewPrimesPillsAndRelayoutsWhenItsWidthGrowsWithoutResettingText() {
    val context = RuntimeEnvironment.getApplication()
    val longLabel = "A very long presentation label for a pill"
    val natural = span(pillStyle { copy(label = longLabel) }).getSize(paint, original, 0, original.length, null)
    assertTrue(natural in 101..299)

    val view = object : AccessibleMarkdownTextView(context) {}
    view.layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.includeFontPadding = false
    view.setTextSize(TypedValue.COMPLEX_UNIT_PX, 16f)

    fun layoutAt(width: Int) {
      view.measure(
        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
      )
      view.layout(0, 0, width, view.measuredHeight)
    }

    val text = SpannableString(original)
    text.setSpan(span(pillStyle { copy(label = longLabel) }), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    view.text = text
    layoutAt(100)
    assertEquals(100f, view.layout.getLineWidth(0), 0f)

    // The old single line still fits the wider view, so TextView would keep its layout.
    val shown = view.text
    layoutAt(300)
    assertEquals(natural.toFloat(), view.layout.getLineWidth(0), 0f)
    assertSame("The text is not re-set to force the relayout", shown, view.text)

    // New text is primed at the width the view already has, before its first layout.
    val next = SpannableString(original)
    val nextPill = span(pillStyle { copy(label = "$longLabel that is longer than the whole view") })
    next.setSpan(nextPill, 0, next.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    view.text = next
    assertEquals(300, nextPill.getSize(paint, next, 0, next.length, null))
  }

  private companion object {
    // Shared with the process-wide icon cache, so it only ever moves forward.
    var now = 0L
  }

  @Test
  fun labelKeepsWeightOfEnclosingBoldText() {
    val text = SpannableString(original)
    val pill = span(style.copy(pill = style.pill?.copy(label = "")))
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 2000)
    val regular = pill.getSize(paint, text, 0, text.length, null)
    val boldPaint = TextPaint(paint).apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD) }
    val bold = pill.getSize(boldPaint, text, 0, text.length, null)
    assertTrue("A pill inside bold text measures its label in bold ($regular vs $bold)", bold > regular)
  }

  @Test
  fun linkTextWithSeveralStyledRunsStillMakesOnePill() {
    // "[**foo** bar](url)": the bold part and the rest are separate runs for the layout.
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true, presentationLabel = "")
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com"),
        children =
          listOf(
            MarkdownASTNode(
              MarkdownASTNode.NodeType.Strong,
              children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, "foo")),
            ),
            MarkdownASTNode(MarkdownASTNode.NodeType.Text, " bar"),
          ),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    val pill = builder.getSpans(0, builder.length, LinkPillSpan::class.java).single()
    LinkPillSpan.prepareForMeasurement(builder, 600)
    val single = pill.getSize(paint, builder, 0, builder.length, null)
    val layout = StaticLayout.Builder.obtain(builder, 0, builder.length, paint, 600).build()
    assertEquals(1, layout.lineCount)
    assertEquals("The line reserves the pill once, not once per styled run", single.toFloat(), layout.getLineWidth(0), 1f)

    val bitmap = Bitmap.createBitmap(600, layout.height, Bitmap.Config.ARGB_8888)
    layout.draw(Canvas(bitmap))
    val row = layout.height / 2
    val painted = (0 until 600).filter { bitmap.getPixel(it, row) != Color.TRANSPARENT }
    assertTrue("Nothing is painted past the single pill", painted.all { it <= single })
  }

  @Test
  fun unmeasuredFallbackWidthDoesNotSqueezePills() {
    val text = SpannableString(original)
    val pill = span()
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertTrue(prepareWidthAwareSpans(text, 300))
    val width = pill.getSize(paint, text, 0, text.length, null)
    // 1 is the fallback for a view nobody has measured yet, not a real width.
    assertFalse(prepareWidthAwareSpans(text, 1))
    assertEquals(width, pill.getSize(paint, text, 0, text.length, null))
  }

  @Test
  fun backgroundMeasurementDoesNotChangeWhatTheVisibleLayoutReserved() {
    val text = SpannableString(original)
    val pill = span(style.copy(pill = style.pill?.copy(label = "A long presentation label for the pill")))
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 400)
    val onScreen = pill.getSize(paint, text, 0, text.length, null)

    var measuredElsewhere = 0
    val worker =
      Thread {
        LinkPillSpan.prepareForMeasurement(text, 60)
        measuredElsewhere = pill.getSize(TextPaint(paint), text, 0, text.length, null)
      }
    worker.start()
    worker.join()

    assertEquals("The off-thread pass measured at its own width", 60, measuredElsewhere)
    assertFalse("The visible side still holds its own limit", LinkPillSpan.prepareForMeasurement(text, 400))
    assertEquals(onScreen, pill.getSize(paint, text, 0, text.length, null))
  }

  @Test
  fun labelUsesTheRunFontUnlessTheLinkNamesAFamily() {
    val text = SpannableString(original)
    val monospace = TextPaint(paint).apply { typeface = Typeface.MONOSPACE }
    val variant = style.copy(pill = style.pill?.copy(label = ""))
    val context = RuntimeEnvironment.getApplication()

    val following = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context, followsRunTypeface = true)
    val withFamily = LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, context, followsRunTypeface = false)
    listOf(following, withFamily).forEach { it.prepareForMeasurement(2000) }

    assertNotEquals(
      "Inline code as link text keeps its code font in the pill",
      withFamily.getSize(monospace, text, 0, text.length, null),
      following.getSize(monospace, text, 0, text.length, null),
    )
    assertEquals(
      "A link font family is not replaced by the run's font",
      withFamily.getSize(paint, text, 0, text.length, null),
      withFamily.getSize(monospace, text, 0, text.length, null),
    )
  }
}

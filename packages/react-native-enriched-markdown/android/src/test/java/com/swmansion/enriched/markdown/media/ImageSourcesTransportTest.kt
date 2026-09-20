package com.swmansion.enriched.markdown.media

import android.graphics.Bitmap
import android.text.SpannableStringBuilder
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [30])
class ImageSourcesTransportTest {
  private val context = RuntimeEnvironment.getApplication()
  private val style =
    StyleConfig(
      JavaOnlyMap.of(
        "image",
        JavaOnlyMap.of(
          "height",
          200.0,
          "maxHeight",
          500.0,
          "aspectRatio",
          0.0,
          "resizeMode",
          "contain",
          "borderRadius",
          0.0,
          "marginTop",
          0.0,
          "marginBottom",
          0.0,
        ),
      ),
      context.also { DisplayMetricsHolder.initDisplayMetrics(it) },
      false,
      0f,
    )

  @Test
  fun pendingHoldsOriginalRemoteUriEvenWhenRawUriIsCached() {
    val raw = "https://original.invalid/pending"
    ImageCache.putOriginal(raw, Bitmap.createBitmap(100, 50, Bitmap.Config.ARGB_8888))
    val span = ImageSpan(context, raw, style, imageSource = ImageSourceTransport(null))
    val sourceField = ImageSpan::class.java.getDeclaredField("sourceDrawable").apply { isAccessible = true }
    assertNull(sourceField.get(span))
    assertEquals(raw, span.imageUrl)
    assertEquals(raw, span.source)
  }

  @Test
  fun resolvedTransportUsesMergedHeadersAndKeepsOriginalCopyUrl() {
    val raw = "original/relative.png"
    val uri = "https://signed.invalid/resolved"
    style.imageRequestHeaders = mapOf("Authorization" to "document", "Accept" to "image/png")
    val merged = mapOf("authorization" to "source", "accept" to "image/png")
    val key = ImageCache.requestKey(uri, merged)
    ImageCache.putOriginal(key, Bitmap.createBitmap(200, 80, Bitmap.Config.ARGB_8888))
    val image =
      MarkdownASTNode(
        NodeType.Image,
        attributes = mapOf("url" to raw),
        imageSource = ImageSourceTransport(uri, mapOf("AUTHORIZATION" to "source")),
      )
    val span = ImageSpan(context, image.getAttribute("url")!!, style, imageSource = image.imageSource)
    val builder = SpannableStringBuilder("\uFFFC")
    builder.setSpan(span, 0, 1, android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val sourceField = ImageSpan::class.java.getDeclaredField("sourceDrawable").apply { isAccessible = true }
    val drawable = sourceField.get(span) as android.graphics.drawable.Drawable
    assertEquals(200, drawable.intrinsicWidth)
    assertEquals(80, drawable.intrinsicHeight)
    assertEquals(raw, span.imageUrl)
    assertTrue(MarkdownExtractor.extractFromSpannable(builder, 0, builder.length).contains(raw))
    assertFalse(MarkdownExtractor.extractFromSpannable(builder, 0, builder.length).contains(uri))
    val boxHeight = ImageSpan::class.java.getDeclaredField("boxHeight").apply { isAccessible = true }
    span.prepareForMeasurement(builder, 320)
    assertEquals(128, boxHeight.getInt(span))
    span.prepareForMeasurement(builder, 640)
    assertEquals(256, boxHeight.getInt(span))
    assertEquals(drawable, sourceField.get(span))
  }

  @Test
  fun cacheIdentityIncludesEffectiveUriAndCaseInsensitiveMergedHeaders() {
    val first = ImageCache.requestKey("https://transport/one", mapOf("Authorization" to "one"))
    assertEquals(first, ImageCache.requestKey("https://transport/one", mapOf("authorization" to "one")))
    assertNotEquals(first, ImageCache.requestKey("https://transport/one", mapOf("authorization" to "two")))
    assertNotEquals(first, ImageCache.requestKey("https://transport/two", mapOf("authorization" to "one")))
    ImageCache.putProcessed(first, 100, 50, 0, "contain", Bitmap.createBitmap(100, 50, Bitmap.Config.ARGB_8888))
    assertNull(
      ImageCache.getProcessed(ImageCache.requestKey("https://transport/two", mapOf("authorization" to "one")), 100, 50, 0, "contain"),
    )
  }

  @Test
  fun effectiveHeadersBypassDiskCacheButUnmodifiedRequestsRetainIt() {
    val authenticated = ImageDownloader.requestForImage("https://transport/image", mapOf("authorization" to "source"))
    assertEquals("source", authenticated.header("authorization"))
    assertTrue(authenticated.cacheControl.noCache)
    assertTrue(authenticated.cacheControl.noStore)
    val unmodified = ImageDownloader.requestForImage("https://transport/image", emptyMap())
    assertFalse(unmodified.cacheControl.noCache)
    assertFalse(unmodified.cacheControl.noStore)
  }
}

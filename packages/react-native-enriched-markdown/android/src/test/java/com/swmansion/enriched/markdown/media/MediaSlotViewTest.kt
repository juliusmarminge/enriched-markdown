package com.swmansion.enriched.markdown.media

import android.util.DisplayMetrics
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [30])
class MediaSlotViewTest {
  @After
  fun resetDisplayMetrics() = DisplayMetricsHolder.setScreenDisplayMetrics(null)

  @Test
  fun measurePassKeepsTheHeightReactMeasuredAtThePixelSnappedWidth() {
    // At 2.8125x the measure pass sees 970.3125px (345dp) while Yoga snaps the view, and so the
    // width React measured the slot at, to 972px (345.6dp).
    DisplayMetricsHolder.setScreenDisplayMetrics(DisplayMetrics().apply { density = 2.8125f })
    val style =
      StyleConfig(
        JavaOnlyMap.of(
          "image",
          JavaOnlyMap.of(
            "height",
            200.0,
            "maxHeight",
            0.0,
            "aspectRatio",
            16.0 / 9.0,
            "resizeMode",
            "cover",
            "borderRadius",
            0.0,
            "marginTop",
            0.0,
            "marginBottom",
            0.0,
          ),
        ),
        RuntimeEnvironment.getApplication(),
        false,
        0f,
      )
    val image = MarkdownASTNode(NodeType.Image, attributes = mapOf("url" to "same"))
    val document = MarkdownASTNode(NodeType.Document, children = listOf(MarkdownASTNode(NodeType.Paragraph, children = listOf(image))))
    val override = MediaOverride("asset-0", 503f, 345.6f, "same", "image", "0.0")
    val slot = mediaSlotsForDocument(DocumentAssets.collect(document), true, 8, 8, listOf(override)).getValue("asset-0")

    assertEquals(1415f, MediaSlotView.heightPx(slot, style, 970.3125f), 0f)
    // A real width change still falls back until React measures again.
    assertEquals(538f, MediaSlotView.heightPx(slot, style, 956f), 0f)
  }
}

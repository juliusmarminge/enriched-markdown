package com.swmansion.enriched.markdown.media

import org.junit.Assert.assertEquals
import org.junit.Test

class MediaSlotFrameTest {
  @Test
  fun nestedOffsetsAccumulateOnceWithoutChangingInnerDimensionsOrOccurrence() {
    val insideNestedQuote = MediaSlotFrame("asset-3", 20, 44, 256, 180)
    // Each parent offset includes its own inset/header and preceding sibling heights.
    val insideOuterQuote = insideNestedQuote.translated(20, 160)
    val inDocument = insideOuterQuote.translated(0, 50)
    assertEquals(MediaSlotFrame("asset-3", 40, 254, 256, 180), inDocument)
    assertEquals(MediaSlotFrame("asset-3", 20, 44, 256, 180), insideNestedQuote)
    // A preceding React media height change moves this occurrence only vertically.
    assertEquals(inDocument.copy(y = 324), insideOuterQuote.translated(0, 120))
  }
}

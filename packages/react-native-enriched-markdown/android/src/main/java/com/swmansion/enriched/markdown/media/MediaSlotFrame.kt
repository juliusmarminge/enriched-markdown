package com.swmansion.enriched.markdown.media

/** Native pixels; conversion to DIP happens once at the root event boundary. */
data class MediaSlotFrame(
  val id: String,
  val x: Int,
  val y: Int,
  val width: Int,
  val height: Int,
) {
  fun translated(
    offsetX: Int,
    offsetY: Int,
  ): MediaSlotFrame = copy(x = x + offsetX, y = y + offsetY)
}

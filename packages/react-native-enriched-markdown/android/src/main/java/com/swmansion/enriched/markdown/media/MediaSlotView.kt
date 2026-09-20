package com.swmansion.enriched.markdown.media

import android.content.Context
import android.view.View
import com.facebook.react.uimanager.PixelUtil
import com.swmansion.enriched.markdown.segments.BlockSegmentView
import com.swmansion.enriched.markdown.styles.StyleConfig
import kotlin.math.ceil

/** A measured, inaccessible native box. React owns its visual and interactive content. */
class MediaSlotView(
  context: Context,
  private val style: StyleConfig,
  slot: MediaSlot,
) : View(context),
  BlockSegmentView {
  var slot: MediaSlot = slot
    set(value) {
      if (field == value) return
      field = value
      requestLayout()
    }

  init {
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    isFocusable = false
  }

  override val segmentMarginTop: Int get() = ceil(marginTop(slot, style)).toInt()
  override val segmentMarginBottom: Int get() = ceil(marginBottom(slot, style)).toInt()

  override fun onMeasure(
    widthMeasureSpec: Int,
    heightMeasureSpec: Int,
  ) {
    val width = MeasureSpec.getSize(widthMeasureSpec)
    setMeasuredDimension(width, ceil(heightPx(slot, style, width.toFloat())).toInt())
  }

  companion object {
    fun marginTop(
      slot: MediaSlot,
      style: StyleConfig,
    ): Float = ceil(if (slot.asset.kind == "video") style.videoStyle.marginTop else style.imageStyle.marginTop)

    fun marginBottom(
      slot: MediaSlot,
      style: StyleConfig,
    ): Float = ceil(if (slot.asset.kind == "video") style.videoStyle.marginBottom else style.imageStyle.marginBottom)

    fun heightPx(
      slot: MediaSlot,
      style: StyleConfig,
      width: Float,
    ): Float {
      val fallback =
        if (slot.asset.kind == "video") {
          width / style.videoStyle.resolvedAspectRatio
        } else {
          val image = style.imageStyle
          val value = if (image.aspectRatio > 0) width / image.aspectRatio else image.height
          if (image.maxHeight > 0) value.coerceAtMost(image.maxHeight) else value
        }
      return ceil(
        PixelUtil.toPixelFromDIP(
          slot.heightForWidth(PixelUtil.toDIPFromPixel(width), PixelUtil.toDIPFromPixel(fallback)),
        ),
      )
    }
  }
}

package com.swmansion.enriched.markdown.media

import android.view.View
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

fun emitMediaEvent(
  view: View,
  name: String,
  data: WritableMap,
): Boolean {
  val context = view.context as ReactContext
  val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id) ?: return false
  dispatcher.dispatchEvent(MediaEvent(UIManagerHelper.getSurfaceId(context), view.id, name, data))
  return true
}

fun documentAssetsEventData(
  revision: Int,
  assets: List<DocumentAsset>,
): WritableMap {
  val entries = Arguments.createArray()
  assets.forEach { asset ->
    entries.pushMap(
      Arguments.createMap().apply {
        putString("id", asset.id)
        putString("kind", asset.kind)
        putString("url", asset.url)
        putString("altText", asset.altText)
        putString("title", asset.title)
        putString("placement", asset.placement)
        putBoolean("eligible", asset.eligible)
        putString("anchor", asset.anchor)
      },
    )
  }
  return Arguments.createMap().apply {
    putInt("revision", revision)
    putArray("assets", entries)
  }
}

private class MediaEvent(
  surfaceId: Int,
  viewId: Int,
  private val name: String,
  private val data: WritableMap,
) : Event<MediaEvent>(surfaceId, viewId) {
  override fun getEventName(): String = name

  override fun getEventData(): WritableMap = data

  override fun canCoalesce(): Boolean = false
}

package com.swmansion.enriched.markdown.media

import com.facebook.react.bridge.ReadableArray
import com.swmansion.enriched.markdown.utils.common.parseImageRequestHeaders

fun parseImageSources(value: ReadableArray?): List<ImageSourceDecision> =
  (0 until (value?.size() ?: 0)).mapNotNull { index ->
    val entry = value?.getMap(index) ?: return@mapNotNull null
    val id = entry.getString("id") ?: return@mapNotNull null
    val url = entry.getString("url") ?: return@mapNotNull null
    val anchor = entry.getString("anchor") ?: return@mapNotNull null
    ImageSourceDecision(
      id,
      url,
      anchor,
      entry.getString("uri") ?: "",
      parseImageRequestHeaders(entry.getArray("headers")),
      entry.getBoolean("useDefault"),
    )
  }

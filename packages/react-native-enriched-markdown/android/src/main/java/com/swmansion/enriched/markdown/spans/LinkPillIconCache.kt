package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File
import kotlin.math.max

/** Original-color local icons, shared by measurement and rendering across reparses. */
internal object LinkPillIconCache {
  private const val MAX_ENTRIES = 64
  private const val MAX_BYTES = 8 * 1024 * 1024
  private const val MAX_DIMENSION = 512

  private data class Key(
    val path: String,
    val modified: Long,
    val size: Long,
  )

  private val images = LinkedHashMap<Key, Bitmap>(16, 0.75f, true)
  private var bytes = 0

  @Synchronized
  fun load(iconUri: String): Bitmap? =
    runCatching {
      val uri = Uri.parse(iconUri)
      if (uri.scheme != "file") return@runCatching null
      val file = File(uri.path ?: return@runCatching null).canonicalFile
      if (!file.isFile) return@runCatching null
      val key = Key(file.path, file.lastModified(), file.length())
      images[key]?.let { return@runCatching it }
      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      BitmapFactory.decodeFile(file.path, bounds)
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
      val options = BitmapFactory.Options().apply { inSampleSize = 1 }
      while (max(bounds.outWidth, bounds.outHeight) / options.inSampleSize > MAX_DIMENSION) {
        options.inSampleSize *= 2
      }
      val bitmap = BitmapFactory.decodeFile(file.path, options) ?: return@runCatching null
      val cost = bitmap.allocationByteCount
      if (cost > MAX_BYTES) return@runCatching bitmap
      images[key] = bitmap
      bytes += cost
      while (images.size > MAX_ENTRIES || bytes > MAX_BYTES) {
        val oldest = images.entries.iterator()
        bytes -= oldest.next().value.allocationByteCount
        oldest.remove()
        // Do not recycle: existing spans can still own the evicted bitmap.
      }
      bitmap
    }.getOrNull()
}

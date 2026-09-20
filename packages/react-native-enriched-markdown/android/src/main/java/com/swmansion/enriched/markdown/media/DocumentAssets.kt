package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import java.util.IdentityHashMap
import kotlin.math.abs

/** Descriptors come from the accepted native AST, including occurrences we cannot override. */
data class DocumentAsset(
  val id: String,
  val kind: String,
  val url: String,
  val altText: String,
  val title: String,
  val placement: String,
  val eligible: Boolean,
  val anchor: String,
)

class DocumentAssets private constructor(
  val assets: List<DocumentAsset>,
  private val byNode: IdentityHashMap<MarkdownASTNode, DocumentAsset>,
) {
  fun assetForNode(node: MarkdownASTNode): DocumentAsset? = byNode[node]

  companion object {
    fun collect(root: MarkdownASTNode): DocumentAssets {
      val assets = mutableListOf<DocumentAsset>()
      val byNode = IdentityHashMap<MarkdownASTNode, DocumentAsset>()

      fun text(node: MarkdownASTNode): String = node.content + node.children.joinToString("") { text(it) }

      fun visit(
        node: MarkdownASTNode,
        parent: MarkdownASTNode?,
        placement: String,
        path: String,
        parentPath: String,
      ) {
        val nestedPlacement =
          when (node.type) {
            MarkdownASTNode.NodeType.Table -> "table"

            MarkdownASTNode.NodeType.UnorderedList,
            MarkdownASTNode.NodeType.OrderedList,
            -> "list"

            MarkdownASTNode.NodeType.Blockquote,
            MarkdownASTNode.NodeType.Admonition,
            -> "blockquote"

            else -> placement
          }
        val kind =
          when (node.type) {
            MarkdownASTNode.NodeType.Image -> "image"
            MarkdownASTNode.NodeType.Video -> "video"
            MarkdownASTNode.NodeType.Link -> "link"
            else -> null
          }
        if (kind != null) {
          val standaloneImage =
            kind == "image" && parent?.type == MarkdownASTNode.NodeType.Paragraph &&
              parent.children.size == 1 && root.children.any { it === parent }
          val eligible = standaloneImage || (kind == "video" && parent === root)
          val asset =
            DocumentAsset(
              id = "asset-${assets.size}",
              kind = kind,
              url = node.getAttribute("url") ?: "",
              altText = text(node).trim(),
              title = node.getAttribute("title") ?: "",
              placement =
                if (eligible) {
                  "block"
                } else if (nestedPlacement == "block") {
                  "inline"
                } else {
                  nestedPlacement
                },
              eligible = eligible,
              anchor = if (standaloneImage) parentPath else path,
            )
          assets.add(asset)
          byNode[node] = asset
        }
        node.children.forEachIndexed { index, child -> visit(child, node, nestedPlacement, "$path.$index", path) }
      }
      visit(root, null, "block", "0", "")
      return DocumentAssets(assets, byNode)
    }
  }
}

/** Values are DIP. A zero width denotes a provisional height, valid at any width. */
data class MediaOverride(
  val id: String,
  val height: Float,
  val width: Float,
  val url: String,
  val kind: String,
  val anchor: String,
) {
  fun matches(asset: DocumentAsset): Boolean =
    asset.eligible && id == asset.id && url == asset.url && kind == asset.kind && anchor == asset.anchor
}

data class MediaSlot(
  val asset: DocumentAsset,
  val measuredOverride: MediaOverride?,
) {
  fun heightForWidth(
    width: Float,
    fallback: Float,
  ): Float {
    val value = measuredOverride ?: return fallback
    return if (value.height.isFinite() && value.height >= 0 &&
      (value.width == 0f || abs(value.width - width) < 0.5f)
    ) {
      value.height
    } else {
      fallback
    }
  }
}

fun mediaSlotsForDocument(
  assets: DocumentAssets,
  enabled: Boolean,
  revision: Int,
  overridesRevision: Int,
  overrides: List<MediaOverride>,
): Map<String, MediaSlot> {
  if (!enabled) return emptyMap()
  val decisions = overrides.associateBy { it.id }
  return assets.assets
    .filter { it.eligible && (overridesRevision != revision || decisions.containsKey(it.id)) }
    .associate { asset -> asset.id to MediaSlot(asset, decisions[asset.id]?.takeIf { it.matches(asset) }) }
}

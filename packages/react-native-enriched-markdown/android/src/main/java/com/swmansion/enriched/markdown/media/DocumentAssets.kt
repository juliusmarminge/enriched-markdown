package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import java.util.IdentityHashMap

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

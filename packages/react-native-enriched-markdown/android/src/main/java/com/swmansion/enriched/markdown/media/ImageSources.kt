package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import java.util.Locale

/** Download transport only. A null URI holds the normal native placeholder. */
data class ImageSourceTransport(
  val uri: String?,
  val headers: Map<String, String> = emptyMap(),
)

data class ImageSourceDecision(
  val id: String,
  val url: String,
  val anchor: String,
  val uri: String,
  val headers: Map<String, String>,
  val useDefault: Boolean,
) {
  fun matches(asset: DocumentAsset): Boolean = asset.kind == "image" && id == asset.id && url == asset.url && anchor == asset.anchor
}

/** Copies accepted AST nodes without changing any semantic attributes or cached parser trees. */
fun withImageSources(
  root: MarkdownASTNode,
  enabled: Boolean,
  documentRevision: Int,
  sourcesRevision: Int,
  continuityStart: Int,
  decisions: List<ImageSourceDecision>,
): MarkdownASTNode {
  if (!enabled) return root
  val assets = DocumentAssets.collect(root)
  val acceptedDecisions =
    if (sourcesRevision >= continuityStart && sourcesRevision <= documentRevision) {
      decisions.associateBy { it.id }
    } else {
      emptyMap()
    }

  fun visit(node: MarkdownASTNode): MarkdownASTNode {
    val children = node.children.map { visit(it) }
    if (node.type != MarkdownASTNode.NodeType.Image) return node.copy(children = children)
    val asset = assets.assetForNode(node)
    val decision = asset?.let { acceptedDecisions[it.id]?.takeIf { source -> source.matches(it) } }
    val transport =
      when {
        decision == null -> ImageSourceTransport(null)
        decision.useDefault -> null
        decision.uri.isBlank() -> ImageSourceTransport(null)
        else -> ImageSourceTransport(decision.uri, decision.headers)
      }
    return node.copy(children = children, imageSource = transport)
  }
  return visit(root)
}

/** HTTP field names are case-insensitive. Per-source values replace document values. */
fun mergeImageRequestHeaders(
  document: Map<String, String>,
  source: Map<String, String>,
): Map<String, String> =
  buildMap {
    document.forEach { (name, value) -> put(name.lowercase(Locale.ROOT), value) }
    source.forEach { (name, value) -> put(name.lowercase(Locale.ROOT), value) }
  }

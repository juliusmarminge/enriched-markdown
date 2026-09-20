package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.media.DocumentAssets
import com.swmansion.enriched.markdown.media.MediaSlot
import com.swmansion.enriched.markdown.parser.MarkdownASTNode

sealed interface MarkdownSegment {
  data class Text(
    val nodes: List<MarkdownASTNode>,
  ) : MarkdownSegment

  data class Table(
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  data class Math(
    val latex: String,
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  data class CodeBlock(
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  data class Blockquote(
    val node: MarkdownASTNode,
    val mediaSlots: Map<String, MediaSlot> = emptyMap(),
    val assets: DocumentAssets? = null,
  ) : MarkdownSegment

  data class Video(
    val node: MarkdownASTNode,
    val mediaSlot: MediaSlot? = null,
  ) : MarkdownSegment
}

fun splitASTIntoSegments(
  root: MarkdownASTNode,
  mediaSlots: Map<String, MediaSlot> = emptyMap(),
  assets: DocumentAssets? = null,
): List<MarkdownSegment> {
  val segments = mutableListOf<MarkdownSegment>()
  val currentTextNodes = mutableListOf<MarkdownASTNode>()

  fun flushTextNodes() {
    if (currentTextNodes.isNotEmpty()) {
      segments.add(MarkdownSegment.Text(currentTextNodes.toList()))
      currentTextNodes.clear()
    }
  }

  for (child in root.children) {
    val mediaNode =
      if (child.type == MarkdownASTNode.NodeType.Paragraph && child.children.size == 1) child.children.first() else child
    val slot = assets?.assetForNode(mediaNode)?.let { mediaSlots[it.id] }
    if (slot != null) {
      flushTextNodes()
      segments.add(MarkdownSegment.Video(mediaNode, slot))
      continue
    }
    when (child.type) {
      MarkdownASTNode.NodeType.Table -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Table(child))
      }

      MarkdownASTNode.NodeType.LatexMathDisplay -> {
        flushTextNodes()
        val latex =
          if (child.children.isNotEmpty()) {
            child.children.first().content
          } else {
            child.content
          }
        segments.add(MarkdownSegment.Math(latex, child))
      }

      MarkdownASTNode.NodeType.CodeBlock -> {
        flushTextNodes()
        segments.add(MarkdownSegment.CodeBlock(child))
      }

      MarkdownASTNode.NodeType.Blockquote,
      MarkdownASTNode.NodeType.Admonition,
      -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Blockquote(child, mediaSlots, assets))
      }

      MarkdownASTNode.NodeType.Video -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Video(child))
      }

      else -> {
        currentTextNodes.add(child)
      }
    }
  }
  flushTextNodes()
  return segments
}

package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import org.junit.Assert.assertEquals
import org.junit.Test

class DocumentAssetsTest {
  private fun image(url: String = "same") =
    MarkdownASTNode(
      NodeType.Image,
      attributes = mapOf("url" to url),
      children = listOf(MarkdownASTNode(NodeType.Text, "alt")),
    )

  private fun paragraph(vararg children: MarkdownASTNode) = MarkdownASTNode(NodeType.Paragraph, children = children.toList())

  private fun document(vararg children: MarkdownASTNode) = MarkdownASTNode(NodeType.Document, children = children.toList())

  @Test
  fun duplicateOccurrencesAndLinksHaveDistinctStableIdsAcrossAppend() {
    val first = image()
    val second = image()
    val link =
      MarkdownASTNode(
        NodeType.Link,
        attributes = mapOf("url" to "destination", "title" to "link title"),
        children = listOf(MarkdownASTNode(NodeType.Strong, children = listOf(MarkdownASTNode(NodeType.Text, "label")))),
      )
    val root = document(paragraph(first), paragraph(link), paragraph(second))
    val before = DocumentAssets.collect(root)
    val after = DocumentAssets.collect(root.copy(children = root.children + paragraph(image("new"))))
    assertEquals(before.assets, after.assets.take(before.assets.size))
    assertEquals(listOf("asset-0", "asset-1", "asset-2"), before.assets.map { it.id })
    assertEquals("asset-0", before.assetForNode(first)?.id)
    assertEquals("asset-2", before.assetForNode(second)?.id)
    assertEquals("link", before.assets[1].kind)
    assertEquals("label", before.assets[1].altText)
    assertEquals("link title", before.assets[1].title)
    assertEquals("alt", before.assets[0].altText)
    assertEquals(listOf("0.0", "0.1.0", "0.2"), before.assets.map { it.anchor })
  }

  @Test
  fun unsupportedPlacementsRemainInManifest() {
    val root =
      document(
        paragraph(image()),
        paragraph(MarkdownASTNode(NodeType.Text, "prefix"), image()),
        MarkdownASTNode(NodeType.UnorderedList, children = listOf(paragraph(image()))),
        MarkdownASTNode(NodeType.Table, children = listOf(image())),
        MarkdownASTNode(NodeType.Blockquote, children = listOf(paragraph(image()))),
      )
    val assets = DocumentAssets.collect(root).assets
    assertEquals(listOf("block", "inline", "list", "table", "blockquote"), assets.map { it.placement })
    assertEquals(listOf(true, false, false, false, false), assets.map { it.eligible })
  }

  @Test
  fun onlyRootVideoSegmentsAreEligible() {
    val video = MarkdownASTNode(NodeType.Video, attributes = mapOf("url" to "movie", "title" to "video title"))
    val assets = DocumentAssets.collect(document(video, MarkdownASTNode(NodeType.Blockquote, children = listOf(video.copy()))))
    assertEquals(listOf("video", "video"), assets.assets.map { it.kind })
    assertEquals(listOf(true, false), assets.assets.map { it.eligible })
    assertEquals(listOf("block", "blockquote"), assets.assets.map { it.placement })
    assertEquals("video title", assets.assets[0].title)
  }
}

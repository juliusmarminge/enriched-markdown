package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
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
    val root = document(video)
    val rootAssets = DocumentAssets.collect(root)
    val slots = mediaSlotsForDocument(rootAssets, true, 9, -1, emptyList())
    val segment = splitASTIntoSegments(root, slots, rootAssets).single() as MarkdownSegment.Video
    assertEquals("video", segment.mediaSlot?.asset?.kind)
    assertEquals("movie", segment.mediaSlot?.asset?.url)
  }

  @Test
  fun unresolvedDecisionReservesSlotAndExplicitNullRestoresNativeSegment() {
    val root = document(paragraph(image()))
    val assets = DocumentAssets.collect(root)
    val provisional = mediaSlotsForDocument(assets, true, 7, -1, emptyList())
    assertNotNull((splitASTIntoSegments(root, provisional, assets).single() as MarkdownSegment.Video).mediaSlot)
    val fallback = mediaSlotsForDocument(assets, true, 7, 7, emptyList())
    assertTrue(splitASTIntoSegments(root, fallback, assets).single() is MarkdownSegment.Text)
    assertTrue(mediaSlotsForDocument(assets, false, 7, -1, emptyList()).isEmpty())
  }

  @Test
  fun carriedDecisionAndWrongWidthAreGuarded() {
    val assets = DocumentAssets.collect(document(paragraph(image())))
    val measuredOverride = MediaOverride("asset-0", 123f, 320f, "same", "image", "0.0")
    val carried = mediaSlotsForDocument(assets, true, 8, 7, listOf(measuredOverride)).getValue("asset-0")
    assertEquals(123f, carried.heightForWidth(320f, 40f), 0f)
    val slot = mediaSlotsForDocument(assets, true, 8, 8, listOf(measuredOverride)).getValue("asset-0")
    assertEquals(123f, slot.heightForWidth(320f, 40f), 0f)
    assertEquals(40f, slot.heightForWidth(400f, 40f), 0f)
    assertEquals(123f, slot.copy(measuredOverride = measuredOverride.copy(width = 0f)).heightForWidth(400f, 40f), 0f)
    assertEquals(40f, slot.copy(measuredOverride = measuredOverride.copy(height = Float.NaN)).heightForWidth(320f, 40f), 0f)
    assertEquals(40f, slot.copy(measuredOverride = measuredOverride.copy(height = -1f)).heightForWidth(320f, 40f), 0f)
  }

  @Test
  fun carriedHeightsRequireOccurrenceIdentityInNewParsedDocument() {
    val original = DocumentAssets.collect(document(paragraph(image())))
    val measurement = MediaOverride("asset-0", 123f, 320f, "same", "image", "0.0")
    val appended = DocumentAssets.collect(document(paragraph(image()), paragraph(image("next"))))
    val carried = mediaSlotsForDocument(appended, true, 8, 7, listOf(measurement))
    assertEquals(123f, carried.getValue("asset-0").heightForWidth(320f, 40f), 0f)
    assertEquals(40f, carried.getValue("asset-1").heightForWidth(320f, 40f), 0f)
    val mismatches = listOf(measurement.copy(url = "different"), measurement.copy(kind = "video"), measurement.copy(anchor = "0.1"))
    mismatches.forEach { mismatch ->
      for (decisionRevision in listOf(7, 8)) {
        val slot = mediaSlotsForDocument(original, true, 8, decisionRevision, listOf(mismatch)).getValue("asset-0")
        assertEquals(40f, slot.heightForWidth(320f, 40f), 0f)
      }
    }
    val shifted = DocumentAssets.collect(document(paragraph(MarkdownASTNode(NodeType.Text, "resolved reference")), paragraph(image())))
    val shiftedSlot = mediaSlotsForDocument(shifted, true, 8, 7, listOf(measurement)).getValue("asset-0")
    assertEquals(40f, shiftedSlot.heightForWidth(320f, 40f), 0f)
    val unsupported = DocumentAssets.collect(document(paragraph(MarkdownASTNode(NodeType.Text, "prefix"), image())))
    assertTrue(mediaSlotsForDocument(unsupported, true, 8, 7, listOf(measurement)).isEmpty())
  }

  @Test
  fun resolvedEarlierReferenceCannotTransferHeightBetweenDuplicateUrls() {
    val before =
      DocumentAssets.collect(
        document(paragraph(MarkdownASTNode(NodeType.Text, "[pending][ref]")), paragraph(image()), paragraph(image())),
      )
    val secondImage = before.assets[1]
    val priorHeight = MediaOverride(secondImage.id, 333f, 320f, secondImage.url, secondImage.kind, secondImage.anchor)
    val referenceLink = MarkdownASTNode(NodeType.Link, attributes = mapOf("url" to "reference"))
    val resolved = DocumentAssets.collect(document(paragraph(referenceLink), paragraph(image()), paragraph(image())))
    val carried = mediaSlotsForDocument(resolved, true, 11, 10, listOf(priorHeight))
    assertEquals(secondImage.id, resolved.assets[1].id)
    assertEquals(secondImage.url, resolved.assets[1].url)
    assertEquals(40f, carried.getValue("asset-1").heightForWidth(320f, 40f), 0f)
    assertEquals(40f, carried.getValue("asset-2").heightForWidth(320f, 40f), 0f)
  }
}

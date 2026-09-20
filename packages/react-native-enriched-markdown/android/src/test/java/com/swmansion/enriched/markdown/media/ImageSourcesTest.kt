package com.swmansion.enriched.markdown.media

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.segments.SegmentSignature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class ImageSourcesTest {
  private fun image() =
    MarkdownASTNode(
      NodeType.Image,
      attributes = mapOf("url" to "relative.png", "title" to "original title"),
      children = listOf(MarkdownASTNode(NodeType.Text, "original alt")),
    )

  private fun document(vararg children: MarkdownASTNode) = MarkdownASTNode(NodeType.Document, children = children.toList())

  private fun resolve(
    root: MarkdownASTNode,
    decisions: List<ImageSourceDecision> = emptyList(),
    sourcesRevision: Int = 5,
    continuityStart: Int = 5,
  ) = withImageSources(root, true, 6, sourcesRevision, continuityStart, decisions)

  @Test
  fun disabledRetainsOriginalTreeAndPendingNeverUsesRawUri() {
    val root = document(image())
    assertSame(root, withImageSources(root, false, 6, 5, 5, emptyList()))
    assertEquals(ImageSourceTransport(null), resolve(root).children.single().imageSource)
    assertNull(root.children.single().imageSource)
  }

  @Test
  fun decisionsValidateRevisionAndOccurrenceIdentity() {
    val root = document(image())
    val source = ImageSourceDecision("asset-0", "relative.png", "0.0", "https://signed", emptyMap(), false)
    assertEquals(
      "https://signed",
      resolve(root, listOf(source))
        .children
        .single()
        .imageSource
        ?.uri,
    )
    for (revision in listOf(4, 7)) {
      assertNull(
        resolve(root, listOf(source), revision)
          .children
          .single()
          .imageSource
          ?.uri,
      )
    }
    for (wrong in listOf(source.copy(id = "asset-1"), source.copy(url = "different"), source.copy(anchor = "0.1"))) {
      assertNull(
        resolve(root, listOf(wrong))
          .children
          .single()
          .imageSource
          ?.uri,
      )
    }
    assertNull(
      resolve(root, listOf(source), continuityStart = 6)
        .children
        .single()
        .imageSource
        ?.uri,
    )
  }

  @Test
  fun explicitDefaultAndDuplicatesAreIndependentAcrossAppend() {
    val root = document(image(), image())
    val first = ImageSourceDecision("asset-0", "relative.png", "0.0", "https://signed/one", emptyMap(), false)
    val second = ImageSourceDecision("asset-1", "relative.png", "0.1", "", emptyMap(), true)
    val resolved = resolve(document(*root.children.toTypedArray(), image()), listOf(first, second))
    assertEquals("https://signed/one", resolved.children[0].imageSource?.uri)
    assertNull(resolved.children[1].imageSource)
    assertEquals(ImageSourceTransport(null), resolved.children[2].imageSource)
    assertEquals(DocumentAssets.collect(root).assets, DocumentAssets.collect(resolved).assets.take(2))
  }

  @Test
  fun nestedAndLinkedImagesRetainAllSemanticAttributes() {
    val linked = MarkdownASTNode(NodeType.Link, attributes = mapOf("url" to "link destination"), children = listOf(image()))
    val root =
      document(
        MarkdownASTNode(NodeType.UnorderedList, children = listOf(image())),
        MarkdownASTNode(NodeType.Table, children = listOf(image())),
        MarkdownASTNode(NodeType.Blockquote, children = listOf(image())),
        linked,
      )
    val assets = DocumentAssets.collect(root).assets
    val decisions =
      assets.filter { it.kind == "image" }.map {
        ImageSourceDecision(it.id, it.url, it.anchor, "https://signed/${it.id}", mapOf("authorization" to it.id), false)
      }
    val resolved = resolve(root, decisions)
    assertEquals(assets, DocumentAssets.collect(resolved).assets)
    resolved.children.forEach { node ->
      val transformedImage = node.children.single()
      assertEquals(image().attributes, transformedImage.attributes)
      assertEquals(image().children, transformedImage.children)
      assertEquals(
        "https://signed/${DocumentAssets.collect(resolved).assetForNode(transformedImage)?.id}",
        transformedImage.imageSource?.uri,
      )
    }
    assertEquals(linked.attributes, resolved.children.last().attributes)
  }

  @Test
  fun sourceHeadersOverrideDocumentHeadersWithoutDuplicateCasing() {
    assertEquals(
      mapOf("authorization" to "source", "accept" to "image/*", "x-source" to "yes"),
      mergeImageRequestHeaders(
        mapOf("Authorization" to "document", "Accept" to "image/*"),
        mapOf(
          "AUTHORIZATION" to "source",
          "X-Source" to "yes",
        ),
      ),
    )
  }

  @Test
  fun reconciliationInvalidatesOnlyWhenTransportChanges() {
    val root = document(image())
    val first = ImageSourceDecision("asset-0", "relative.png", "0.0", "https://signed/one", emptyMap(), false)
    val resolved = resolve(root, listOf(first))
    val pending = resolve(root)
    assertNotEquals(SegmentSignature.signatureForNode(resolved), SegmentSignature.signatureForNode(pending))
    assertNotEquals(SegmentSignature.signatureForNode(pending), SegmentSignature.signatureForNode(root))
    assertNotEquals(
      SegmentSignature.signatureForNode(resolved),
      SegmentSignature.signatureForNode(resolve(root, listOf(first.copy(headers = mapOf("authorization" to "new"))))),
    )
    val appended = resolve(document(*root.children.toTypedArray(), image()), listOf(first))
    assertEquals(SegmentSignature.signatureForNode(resolved.children[0]), SegmentSignature.signatureForNode(appended.children[0]))
  }

  @Test
  fun originalFourArgumentConstructorRemainsAvailableToNativeParser() {
    val constructor =
      MarkdownASTNode::class.java.getConstructor(NodeType::class.java, String::class.java, Map::class.java, List::class.java)
    val node = constructor.newInstance(NodeType.Image, "", mapOf("url" to "original"), emptyList<MarkdownASTNode>())
    assertEquals("original", node.getAttribute("url"))
    assertNull(node.imageSource)
  }
}

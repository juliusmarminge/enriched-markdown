package com.swmansion.enriched.markdown.parser

import com.swmansion.enriched.markdown.media.ImageSourceTransport

data class MarkdownASTNode(
  val type: NodeType,
  val content: String = "",
  val attributes: Map<String, String> = emptyMap(),
  val children: List<MarkdownASTNode> = emptyList(),
  val imageSource: ImageSourceTransport? = null,
) {
  // Preserve the exact four-argument constructor used by the JNI parser.
  constructor(
    type: NodeType,
    content: String,
    attributes: Map<String, String>,
    children: List<MarkdownASTNode>,
  ) : this(type, content, attributes, children, null)

  enum class NodeType {
    Document,
    Paragraph,
    Text,
    Link,
    Heading,
    LineBreak,
    Strong,
    Emphasis,
    Strikethrough,
    Underline,
    Code,
    Image,
    Blockquote,
    UnorderedList,
    OrderedList,
    ListItem,
    CodeBlock,
    ThematicBreak,
    Table,
    TableHead,
    TableBody,
    TableRow,
    TableHeaderCell,
    TableCell,
    LatexMathInline,
    LatexMathDisplay,
    Spoiler,
    Superscript,
    Subscript,
    Highlight,
    SoftBreak,
    BlankLine,
    Admonition,
    Video,
  }

  fun getAttribute(key: String): String? = attributes[key]
}

// A node type that md4c emits as a standalone block stacked vertically, as opposed to an inline span.
internal fun MarkdownASTNode.NodeType.isTopLevelBlock(): Boolean =
  when (this) {
    MarkdownASTNode.NodeType.Paragraph,
    MarkdownASTNode.NodeType.Heading,
    MarkdownASTNode.NodeType.Blockquote,
    MarkdownASTNode.NodeType.Admonition,
    MarkdownASTNode.NodeType.UnorderedList,
    MarkdownASTNode.NodeType.OrderedList,
    MarkdownASTNode.NodeType.CodeBlock,
    MarkdownASTNode.NodeType.ThematicBreak,
    MarkdownASTNode.NodeType.BlankLine,
    MarkdownASTNode.NodeType.Table,
    MarkdownASTNode.NodeType.LatexMathDisplay,
    MarkdownASTNode.NodeType.Video,
    -> true

    else -> false
  }

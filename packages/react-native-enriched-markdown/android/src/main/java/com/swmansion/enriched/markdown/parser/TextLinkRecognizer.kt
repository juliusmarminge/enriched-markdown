package com.swmansion.enriched.markdown.parser

import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.utils.common.LinkRegexConfig
import java.util.regex.Pattern

/** Native regex parity with iOS ENRMTextLinkRecognizer, applied before AST consumers. */
object TextLinkRecognizer {
  fun recognize(
    ast: MarkdownASTNode,
    linkRegex: LinkRegexConfig? = null,
    inlineCodeLinkRegex: LinkRegexConfig? = null,
  ): MarkdownASTNode {
    val textPattern = linkRegex?.compiled
    val codePattern = inlineCodeLinkRegex?.compiledWholeSpan
    if (textPattern == null && codePattern == null) return ast

    val pass = Pass(textPattern, codePattern)
    // Documents are containers, so recognition never changes their root type.
    val children = pass.transformChildren(ast.children)
    return if (children === ast.children) ast else ast.copy(children = children)
  }

  private class Pass(
    private val textPattern: Pattern?,
    private val codePattern: Pattern?,
  ) {
    fun transform(node: MarkdownASTNode): List<MarkdownASTNode> {
      when (node.type) {
        NodeType.Link, NodeType.CodeBlock, NodeType.Image, NodeType.Video,
        NodeType.LatexMathInline, NodeType.LatexMathDisplay,
        -> {
          return listOf(node)
        }

        NodeType.Code -> {
          // Code renderers concatenate the parser's text children verbatim.
          val content = node.children.joinToString("") { it.content }
          val matcher = codePattern?.matcher(content)
          if (content.isNotEmpty() && matcher != null && matcher.find() && matcher.start() == 0 && matcher.end() == content.length) {
            return listOf(link(node, content))
          }
          return listOf(node)
        }

        NodeType.Text -> {
          val matcher = textPattern?.matcher(node.content) ?: return listOf(node)
          val result = mutableListOf<MarkdownASTNode>()
          var offset = 0
          while (matcher.find()) {
            val start = matcher.start()
            val end = matcher.end()
            if (start == end) continue
            if (start > offset) result.add(node.copy(content = node.content.substring(offset, start)))
            val matched = node.content.substring(start, end)
            result.add(link(node.copy(content = matched), matched))
            offset = end
          }
          if (offset == 0) return listOf(node)
          if (offset < node.content.length) result.add(node.copy(content = node.content.substring(offset)))
          return result
        }

        else -> {
          val children = transformChildren(node.children)
          return listOf(if (children === node.children) node else node.copy(children = children))
        }
      }
    }

    /** Returns the same list when no child changed, so untouched subtrees are not copied. */
    fun transformChildren(children: List<MarkdownASTNode>): List<MarkdownASTNode> {
      var result: MutableList<MarkdownASTNode>? = null
      children.forEachIndexed { index, child ->
        val transformed = transform(child)
        val unchanged = transformed.size == 1 && transformed[0] === child
        if (result == null) {
          if (unchanged) return@forEachIndexed
          result = children.subList(0, index).toMutableList()
        }
        result.addAll(transformed)
      }
      return result ?: children
    }

    private fun link(
      child: MarkdownASTNode,
      url: String,
    ): MarkdownASTNode =
      MarkdownASTNode(
        NodeType.Link,
        attributes = mapOf("url" to url, "recognizedLink" to "true"),
        children = listOf(child),
      )
  }
}

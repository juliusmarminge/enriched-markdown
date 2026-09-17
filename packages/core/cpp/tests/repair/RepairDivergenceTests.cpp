// Cases where the port deliberately differs from the reference, plus the
// md4c extensions it has no counterpart for. Every behaviour asserted here is
// listed in the MarkdownRepair.hpp header; the recorded reference cases that
// changed because of it are marked `// ours` in ReferenceCases.cpp.
#include <string>

#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {
std::string repair(std::string_view s, const RepairOptions &o = RepairOptions()) {
  return repairInlineMarkdown(s, o);
}
} // namespace

TEST_CASE("constructs opened before a placeholder link are still closed") {
  // The reference stops the pipeline after the placeholder (our divergence).
  CHECK(repair("**bold [link") == "**bold [link](streamdown:incomplete-link)**");
  CHECK(repair("*a [b](http://x") == "*a [b](streamdown:incomplete-link)*");
  CHECK(repair("[**bold link") == "[**bold link**](streamdown:incomplete-link)");
  CHECK(repair("see [a *b") == "see [a *b*](streamdown:incomplete-link)");
  CHECK(repair("`code [not a link") == "`code [not a link`");
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("**bold [link", o) == "**bold link**");
}

TEST_CASE("brackets that are not links") {
  CHECK(repair("- [") == "- [");
  CHECK(repair("- [ ") == "- ["); // trailing space trimmed as usual
  CHECK(repair("- [x") == "- [x");
  CHECK(repair("1. [ ] todo **b") == "1. [ ] todo **b**");
  CHECK(repair("- [link") == "- [link](streamdown:incomplete-link)");
  CHECK(repair("> [!NO") == "> [!NO");
  CHECK(repair("> [!NOTE]\n> text **b") == "> [!NOTE]\n> text **b**");
  CHECK(repair("note[^1") == "note[^1");
  CHECK(repair("[text][re") == "[text][re");
  CHECK(repair("see [x") == "see [x](streamdown:incomplete-link)");
}

TEST_CASE("md4c extensions") {
  CHECK(repair("||hidden") == "||hidden||");
  CHECK(repair("||a|| and ||b") == "||a|| and ||b||");
  CHECK(repair("| a | b") == "| a | b"); // single pipes are tables, not spoilers
  RepairOptions o;
  o.highlight = o.superscript = o.subscript = true;
  CHECK(repair("==mark", o) == "==mark==");
  CHECK(repair("x^2", o) == "x^2^");
  CHECK(repair("x^ 2", o) == "x^ 2"); // an opener before whitespace is literal
  CHECK(repair("H~2", o) == "H~2~");
  CHECK(repair("H~2~O and ~~s", o) == "H~2~O and ~~s~~");
  CHECK(repair("20~25", o) == "20~25~"); // subscript on: no single-tilde escape
  CHECK(repair("20~25") == "20\\~25");   // subscript off: reference behaviour
  CHECK(repair("`x^2`", o) == "`x^2`");
}

TEST_CASE("openers in an earlier block are left alone") {
  CHECK(repair("**Note\n\nNext paragraph") == "**Note\n\nNext paragraph");
  CHECK(repair("**a\n \n_b") == "**a\n \n_b_"); // a whitespace-only line is blank; only the last opener closes
  CHECK(repair("## **Setup\nSome text") == "## **Setup\nSome text");
  CHECK(repair("## **Setup") == "## **Setup**");
  CHECK(repair("[link\n\nmore") == "[link\n\nmore");
  CHECK(repair("$$\nx\n\ny") == "$$\nx\n\ny");
  CHECK(repair("**a\nb") == "**a\nb**"); // a soft break stays inside the paragraph
}

TEST_CASE("line endings") {
  CHECK(repair("**b\r\n") == "**b**\r\n");
  CHECK(repair("**b\r\n\r\n") == "**b**\r\n\r\n");
}

TEST_CASE("full pipeline: mixed") {
  CHECK(repair("This is **bold with *ital") == "This is **bold with *ital***");
  // Closers nest in reverse opening order (our divergence from the reference).
  CHECK(repair("Text **bold `code") == "Text **bold `code`**");
  CHECK(repair("**bold ~~strike") == "**bold ~~strike~~**");
  CHECK(repair("~~strike with **bold") == "~~strike with **bold**~~");
  CHECK(repair("$$\nx\n") == "$$\nx\n$$\n");
  CHECK(repair("$$a\nb$$ $$c") == "$$a\nb$$ $$c$$"); // only the open block decides single- vs multi-line
  CHECK(repair("**bold\n") == "**bold**\n");
  CHECK(repair("**a `b\n\n") == "**a `b`**\n\n");
  CHECK(repair("~~s **b *i\n") == "~~s **b *i***~~\n");
  CHECK(repair("`g **c") == "`g **c`"); // ** inside an open code span is code, not emphasis
  CHECK(repair("| a | b |\n|---|---|\n| **x") == "| a | b |\n|---|---|\n| **x**");
}

// Hand-written cases for the repair module. ReferenceCases.cpp covers parity
// with the reference implementation; these pin the behaviours we care about
// by name so a regression points at the handler, not at "case 412".
#include <string>

#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {

std::string repair(std::string_view s, const RepairOptions &o = RepairOptions()) {
  return repairInlineMarkdown(s, o);
}

using RepairInternal::RepairContext;

// Runs one handler on its own context and returns the resulting text.
template <class Handler> auto handler(Handler h) {
  return [h](std::string_view s) {
    std::string text(s);
    RepairContext ctx(text);
    h(ctx);
    return text;
  };
}

const auto linksProtocol = handler([](RepairContext &c) { RepairHandlers::links(c, LinkMode::Protocol); });
const auto linksTextOnly = handler([](RepairContext &c) { RepairHandlers::links(c, LinkMode::TextOnly); });

} // namespace

TEST_CASE("pipeline: trailing single space is dropped, double space kept") {
  CHECK(repair("hello ") == "hello");
  CHECK(repair("hello  ") == "hello  ");
  CHECK(repair("") == "");
}

TEST_CASE("bold") {
  auto bold = handler(RepairHandlers::bold);
  CHECK(bold("**bold") == "**bold**");
  CHECK(bold("**bold*") == "**bold**");
  CHECK(bold("**bold**") == "**bold**");
  CHECK(bold("**") == "**");
  CHECK(bold("` **bold`") == "` **bold`");
  CHECK(bold("```\n**bold\n") == "```\n**bold\n");
  CHECK(bold("- item\n**bold\nmore") == "- item\n**bold\nmore**");
  CHECK(bold("***") == "***"); // horizontal rule, not bold
}

TEST_CASE("italic") {
  auto asterisk = handler(RepairHandlers::italicSingleAsterisk);
  auto underscore = handler(RepairHandlers::italicSingleUnderscore);
  auto doubleUnderscore = handler(RepairHandlers::italicDoubleUnderscore);
  CHECK(asterisk("*it") == "*it*");
  CHECK(asterisk("hello*world") == "hello*world");
  CHECK(asterisk("* item") == "* item");
  CHECK(asterisk("2 * 3") == "2 * 3");
  CHECK(underscore("_it") == "_it_");
  CHECK(underscore("snake_case") == "snake_case");
  CHECK(underscore("_it\n\n") == "_it_\n\n");
  CHECK(underscore("**bold _und**") == "**bold _und_**");
  CHECK(doubleUnderscore("__it") == "__it__");
  CHECK(doubleUnderscore("__it_") == "__it__");
}

TEST_CASE("bold italic") {
  auto boldItalic = handler(RepairHandlers::boldItalic);
  CHECK(boldItalic("***x") == "***x***");
  CHECK(boldItalic("****") == "****");
  CHECK(boldItalic("**bold and *italic***") == "**bold and *italic***");
}

TEST_CASE("inline code") {
  auto inlineCode = handler(RepairHandlers::inlineCode);
  CHECK(inlineCode("`code") == "`code`");
  CHECK(inlineCode("`code`") == "`code`");
  CHECK(inlineCode("```js\ncode") == "```js\ncode");
  CHECK(inlineCode("```code``") == "```code```");
  CHECK(inlineCode("\\`not code") == "\\`not code");
}

TEST_CASE("strikethrough and single tilde") {
  auto strikethrough = handler(RepairHandlers::strikethrough);
  auto singleTilde = handler(RepairHandlers::singleTilde);
  CHECK(strikethrough("~~gone") == "~~gone~~");
  CHECK(strikethrough("~~gone~") == "~~gone~~");
  CHECK(singleTilde("20~25") == "20\\~25");
  CHECK(singleTilde("a~~b") == "a~~b");
  CHECK(singleTilde("`20~25`") == "`20~25`");
  CHECK(singleTilde("温~度") == "温\\~度"); // Unicode letters
  CHECK(singleTilde("a~b~c") == "a\\~b\\~c");
}

TEST_CASE("links and images") {
  CHECK(linksProtocol("[text](http://x") == "[text](streamdown:incomplete-link)");
  CHECK(linksTextOnly("[text](http://x") == "text");
  CHECK(linksProtocol("see [text") == "see [text](streamdown:incomplete-link)");
  CHECK(linksTextOnly("see [text") == "see text");
  CHECK(linksProtocol("![alt](http://x") == "");
  CHECK(linksProtocol("pic ![alt") == "pic ");
  CHECK(linksTextOnly("[a](b) and [c") == "[a](b) and c");
  CHECK(linksProtocol("`[not a link`") == "`[not a link`");
}

TEST_CASE("pipeline stops after a placeholder link in protocol mode") {
  CHECK(repair("**bold [link") == "**bold [link](streamdown:incomplete-link)");
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("**bold [link", o) == "**bold link**");
}

TEST_CASE("math") {
  auto katex = handler(RepairHandlers::katex);
  auto inlineKatex = handler(RepairHandlers::inlineKatex);
  CHECK(katex("$$x") == "$$x$$");
  CHECK(katex("$$\nx") == "$$\nx\n$$");
  CHECK(katex("$$x$") == "$$x$$");
  CHECK(katex("`$$x`") == "`$$x`");
  CHECK(inlineKatex("$x") == "$x$");
  CHECK(inlineKatex("costs $5 and $6") == "costs $5 and $6");
  CHECK(repair("$$ a * b") == "$$ a * b$$"); // asterisk inside math stays
}

TEST_CASE("html tags and comparison operators") {
  auto htmlTags = handler(RepairHandlers::htmlTags);
  auto comparison = handler(RepairHandlers::comparisonOperators);
  CHECK(htmlTags("text <cus") == "text");
  CHECK(htmlTags("text <b>bold</b") == "text <b>bold");
  CHECK(htmlTags("a < b") == "a < b");
  CHECK(htmlTags("`<cus") == "`<cus");
  CHECK(comparison("- > 25: costly") == "- \\> 25: costly");
  CHECK(comparison("1. >= $5") == "1. \\>= $5");
  CHECK(comparison("- > quote") == "- > quote");
  CHECK(comparison("> 5") == "> 5");
}

TEST_CASE("setext headings") {
  auto setext = handler(RepairHandlers::setextHeadings);
  CHECK(setext("Title\n-") == "Title\n-\xE2\x80\x8B");
  CHECK(setext("Title\n--") == "Title\n--\xE2\x80\x8B");
  CHECK(setext("Title\n---") == "Title\n---");
  CHECK(setext("Title\n- ") == "Title\n- ");
  CHECK(setext("\n-") == "\n-");
  CHECK(setext("Title\n=") == "Title\n=\xE2\x80\x8B");
}

TEST_CASE("options disable individual handlers") {
  RepairOptions o;
  o.bold = false;
  CHECK(repair("**x", o) == "**x");
  o = RepairOptions();
  o.links = false;
  o.images = false;
  CHECK(repair("[x](y", o) == "[x](y");
  o = RepairOptions();
  o.links = false; // images alone keeps the handler on, as upstream
  CHECK(repair("[x](y", o) == "[x](streamdown:incomplete-link)");
}

TEST_CASE("helpers") {
  CHECK(isWordChar('a'));
  CHECK(isWordChar('_'));
  CHECK(isWordChar(0x4E2D));  // 中
  CHECK(isWordChar(0x1D400)); // 𝐀 (full code point view)
  CHECK_FALSE(isWordChar(' '));
  CHECK_FALSE(isWordChar(0x1F600)); // 😀
  CHECK_FALSE(isWordChar(kNoCodePoint));
  CHECK(isWithinCodeBlock("```\nx", 4));
  CHECK_FALSE(isWithinCodeBlock("```\nx\n```\ny", 10));
  CHECK(isWithinMathBlock("$x$ $y", 5));
  CHECK_FALSE(isWithinMathBlock("$x$ y", 4));
  CHECK(isWithinMathBlock("\\(a_b\\)", 3));
  CHECK(isWithinLinkOrImageUrl("[a](b_c)", 5));
  CHECK_FALSE(isWithinLinkOrImageUrl("(b_c)", 2));
}

TEST_CASE("unicode neighbours of markers") {
  // Word-internal detection must decode code points, not bytes.
  CHECK(repair("naïve*word") == "naïve*word");
  CHECK(repair("naïve _x") == "naïve _x_");
  CHECK(repair("日本語_テスト") == "日本語_テスト");
  // Astral characters are not word characters in the reference (UTF-16 view).
  CHECK(repair("😀*wave") == "😀*wave*");
}

TEST_CASE("in-place entry point matches the copying one") {
  std::string text = "**bold [link](http://x";
  repairInlineMarkdownInPlace(text, RepairOptions());
  CHECK(text == repair("**bold [link](http://x"));
  text = "";
  repairInlineMarkdownInPlace(text, RepairOptions());
  CHECK(text.empty());
}

TEST_CASE("full pipeline: mixed") {
  CHECK(repair("This is **bold with *ital") == "This is **bold with *ital*");
  CHECK(repair("Text **bold `code") == "Text **bold `code**`");
  CHECK(repair("| a | b |\n|---|---|\n| **x") == "| a | b |\n|---|---|\n| **x**");
}

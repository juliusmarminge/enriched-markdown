// Runs every case in ReferenceCases.cpp through the port and asserts byte
// equality with the recorded output.
#include <string>

#include "MarkdownRepair.hpp"
#include "ReferenceCases.hpp"
#include "RepairInternal.hpp"
#include "doctest/doctest.h"

namespace {

// Makes control characters visible in failure output.
std::string show(std::string_view s) {
  std::string out;
  for (const char c : s) {
    if (c == '\n') {
      out += "\\n";
    } else if (c == '\t') {
      out += "\\t";
    } else {
      out.push_back(c);
    }
  }
  return out;
}

} // namespace

TEST_CASE("reference parity: recorded cases") {
  REQUIRE(ReferenceCases::kCaseCount > 100);
  for (size_t i = 0; i < ReferenceCases::kCaseCount; ++i) {
    const ReferenceCases::Case &c = ReferenceCases::kCases[i];
    const std::string actual = Markdown::repairInlineMarkdown(c.input, c.options);
    CHECK_MESSAGE(actual == c.expected, "case " << i << "\ninput:    " << show(c.input) << "\nexpected: "
                                                << show(c.expected) << "\nactual:   " << show(actual));
  }
}

TEST_CASE("reference parity: exported helpers") {
  using ReferenceCases::Helper;
  REQUIRE(ReferenceCases::kHelperCallCount > 0);
  for (size_t i = 0; i < ReferenceCases::kHelperCallCount; ++i) {
    const ReferenceCases::HelperCall &h = ReferenceCases::kHelperCalls[i];
    bool actual = false;
    switch (h.fn) {
      case Helper::IsWordChar:
        actual = Markdown::isWordChar(h.argument);
        break;
      case Helper::IsWithinCodeBlock:
        actual = Markdown::isWithinCodeBlock(h.text, h.argument);
        break;
      case Helper::IsWithinMathBlock:
        actual = Markdown::isWithinMathBlock(h.text, h.argument);
        break;
      case Helper::IsWithinLinkOrImageUrl:
        actual = Markdown::isWithinLinkOrImageUrl(h.text, h.argument);
        break;
    }
    CHECK_MESSAGE(actual == h.expected, "helper call " << i << " (" << show(h.text) << ", " << h.argument << ")");
  }
}

// The forward-pass lookup must agree with the backward-walking public
// functions on every position of every recorded input, so the recorded cases
// double as an oracle for the fast path.
TEST_CASE("line-context lookup agrees with the reference helpers") {
  size_t positions = 0;
  for (size_t i = 0; i < ReferenceCases::kCaseCount; ++i) {
    const std::string_view text = ReferenceCases::kCases[i].input;
    const Markdown::RepairInternal::LineContextLookup lookup(text);
    for (size_t p = 0; p <= text.size(); ++p, ++positions) {
      CHECK_MESSAGE(lookup.insideLinkUrl(p) == Markdown::isWithinLinkOrImageUrl(text, p),
                    "insideLinkUrl(" << show(text) << ", " << p << ")");
      CHECK_MESSAGE(lookup.insideHtmlTag(p) == Markdown::RepairInternal::isWithinHtmlTag(text, p),
                    "insideHtmlTag(" << show(text) << ", " << p << ")");
    }
  }
  // Shapes the recorded cases do not cover: an unclosed URL, a bare paren
  // after a link paren, nested link parens, a paren inside inline code.
  for (const std::string_view text : {"[a](url _x", "[a](b(c) d) e", "[a](b [c](d) e) f", "x (y) [a](z)",
                                      "<a href=\"_x\">_y</a> <b _c", "a\n(b) [c](d\ne)"}) {
    const Markdown::RepairInternal::LineContextLookup lookup(text);
    for (size_t p = 0; p <= text.size(); ++p, ++positions) {
      CHECK_MESSAGE(lookup.insideLinkUrl(p) == Markdown::isWithinLinkOrImageUrl(text, p),
                    "insideLinkUrl(" << show(text) << ", " << p << ")");
      CHECK_MESSAGE(lookup.insideHtmlTag(p) == Markdown::RepairInternal::isWithinHtmlTag(text, p),
                    "insideHtmlTag(" << show(text) << ", " << p << ")");
    }
  }
  CHECK(positions > 10000);
}

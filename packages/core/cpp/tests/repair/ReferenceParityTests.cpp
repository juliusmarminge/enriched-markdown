// Runs every case in ReferenceCases.cpp through the port and asserts byte
// equality with the recorded output.
#include <string>

#include "MarkdownRepair.hpp"
#include "ReferenceCases.hpp"
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

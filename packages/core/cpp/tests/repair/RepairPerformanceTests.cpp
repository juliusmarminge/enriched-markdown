// Guards against the two ways this module could get slow again: a scan that
// is quadratic in line length (streamed paragraphs are unwrapped, so line
// length grows with the paragraph), and a gross per-call regression. Timing
// assertions only run in optimised builds; a Debug build checks that the
// code runs, not how fast.
#include <chrono>
#include <string>

#include "MarkdownRepair.hpp"
#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {

// A paragraph with no parentheses or angle brackets, so every `_` used to
// walk back to the line start.
std::string paragraphOfUnderscores(size_t chars) {
  std::string p;
  while (p.size() < chars) {
    p += "some_variable_name and _emphasis_ text ";
  }
  return p;
}

std::string document(size_t paragraphs, size_t charsPerParagraph) {
  std::string doc;
  for (size_t i = 0; i < paragraphs; ++i) {
    doc += paragraphOfUnderscores(charsPerParagraph) + "\n\n";
  }
  return doc + "and _open";
}

double millisecondsPerCall(const std::string &doc, int iterations) {
  size_t sink = 0;
  const auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < iterations; ++i) {
    sink += repairInlineMarkdown(doc, {}).size();
  }
  const auto end = std::chrono::steady_clock::now();
  CHECK(sink > 0);
  return std::chrono::duration<double, std::milli>(end - start).count() / iterations;
}

} // namespace

TEST_CASE("repair cost is linear in line length") {
  const std::string shortLines = document(8, 4000);
  const std::string longLines = document(8, 16000); // 4x the line length
  const double shortMs = millisecondsPerCall(shortLines, 5);
  const double longMs = millisecondsPerCall(longLines, 5);
  MESSAGE("8 x 4000: " << shortMs << " ms, 8 x 16000: " << longMs << " ms");
#ifdef NDEBUG
  // Linear scaling gives ~4x; a scan quadratic in line length gives ~16x.
  CHECK(longMs < 8 * shortMs);
#endif
}

TEST_CASE("repair of a 64 KB document stays within budget") {
  const std::string doc = document(8, 8000);
  const double ms = millisecondsPerCall(doc, 5);
  MESSAGE("64 KB: " << ms << " ms");
#ifdef NDEBUG
  // ~1 ms on a laptop; the budget is deliberately loose so CI noise cannot
  // fail it, while a quadratic regression (20 ms and up) still does.
  CHECK(ms < 10.0);
#endif
}

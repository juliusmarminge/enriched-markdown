// Cases from the review of PR #830, most important first. Every CHECK fails on
// fb5d7d8b unless marked otherwise; `// today:` shows the current output.
#include <string>

#include "MarkdownRepair.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {
std::string repair(std::string_view s, const RepairOptions &o = RepairOptions()) {
  return repairInlineMarkdown(s, o);
}
} // namespace

// The italic handlers anchor the closer at the first `*`/`_` in the text instead of the
// open one (RepairEmphasis.cpp:295, :318), so with the earlier-block rule an italic in any
// previous paragraph disables italic repair for the rest of the stream. Bold is fine.
TEST_CASE("italic closer is anchored at the open marker") {
  CHECK(repair("This is *important*.\n\nNext *point") == "This is *important*.\n\nNext *point*"); // today: unchanged
  CHECK(repair("This is _important_.\n\nNext _point") == "This is _important_.\n\nNext _point_"); // today: unchanged
  CHECK(repair("# *Title*\nsome *text") == "# *Title*\nsome *text*");                             // today: unchanged
  CHECK(repair("_ x **y _z") == "_ x **y _z_**"); // today: _ x **y _z**_
}

// An escaped `\[` is repaired as a link opener (RepairHandlers.cpp:208). LLMs stream
// `\[ … \]` for display math, so the placeholder shows up as literal text.
TEST_CASE("an escaped bracket is not a link") {
  CHECK(repair("Solve \\[ x^2 + y^2") ==
        "Solve \\[ x^2 + y^2");                                // today: Solve \[ x^2 + y^2](streamdown:incomplete-link)
  CHECK(repair("see \\[a](http://x") == "see \\[a](http://x"); // today: see \[a](streamdown:incomplete-link)
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("Solve \\[ x^2", o) == "Solve \\[ x^2"); // today: Solve \ x^2
}

// Both math handlers use `rfind` as the opener (RepairHandlers.cpp:365, :400), which can be
// half of a `$$`, an escaped `\$` or a `$$` inside inline code, so the earlier-block check
// and the nesting order work from the wrong index.
TEST_CASE("math closers are anchored at their opener") {
  RepairOptions o;
  o.inlineKatex = true;
  CHECK(repair("It costs $5.\n\nThe formula $$x^2$$", o) ==
        "It costs $5.\n\nThe formula $$x^2$$");        // today: ...$$x^2$$$
  CHECK(repair("$a **b \\$5", o) == "$a **b \\$5**$"); // today: $a **b \$5$**
  CHECK(repair("$$a\n\n`$$` b") == "$$a\n\n`$$` b");   // today: $$a\n\n`$$` b$$
  CHECK(repair("$$a **b `$$`") == "$$a **b `$$`**$$"); // today: $$a **b `$$`$$**
}

// A CRLF blank line is not a block boundary (RepairInternal.cpp:438), although a trailing
// CRLF already is.
TEST_CASE("a CRLF blank line is a block boundary") {
  CHECK(repair("**a\r\n\r\nb") == "**a\r\n\r\nb");           // today: **a\r\n\r\nb**
  CHECK(repair("[link\r\n\r\nmore") == "[link\r\n\r\nmore"); // today: [link\r\n\r\nmore](streamdown:incomplete-link)
}

// countSingleUnderscores applies a flanking rule the reference does not have. Good change,
// but it is missing from the divergence list in MarkdownRepair.hpp. These pass today.
TEST_CASE("underscore flanking rule, pinned") {
  CHECK(repair("_a_ b_") == "_a_ b_"); // reference: _a_ b__
  CHECK(repair("_  b") == "_  b");     // reference: _  b_
}

// The task-list check accepts any word starting with x (RepairHandlers.cpp:225), so a link
// whose text starts with x is not repaired until its `](` arrives.
TEST_CASE("task-list check only matches a checkbox") {
  CHECK(repair("- [Xcode setup") == "- [Xcode setup](streamdown:incomplete-link)"); // today: unchanged
  CHECK(repair("- [x") == "- [x");                                                  // guard, passes today
}

// Optional follow-up: a fence or a heading after the opener ends its paragraph like a blank
// line does (RepairInternal.cpp:469). The reference has the same gap.
TEST_CASE("a fence or heading after the opener is a block boundary") {
  CHECK(repair("**a\n```\ncode") ==
        "**a\n```\ncode"); // today: **a\n```\ncode**  the closer lands inside the code block
  CHECK(repair("**a\n# heading") == "**a\n# heading"); // today: **a\n# heading**
}

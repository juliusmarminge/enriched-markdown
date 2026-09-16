// Repair of incomplete markdown for streaming: closes the `**`, `[link](`,
// `$$` and similar constructs left open at the end of a streamed prefix, so
// the parser renders it the way the finished document will.
//
// Attribution: this module is a C++ port of remend 1.3.1 by Vercel, licensed
// under Apache-2.0; see LICENSE.remend in this directory. Below, "the
// reference" means that implementation. Handler names, option names, defaults
// and run order match it, and the tests in packages/core/cpp/tests replay its
// test suite against this port. When changing anything here, run
// `yarn core:test`.
//
// Source layout, mirroring the reference's:
//   MarkdownRepair.cpp   pipeline and public helpers        (index.ts, utils.ts)
//   RepairEmphasis.cpp   bold / italic / bold-italic        (emphasis-handlers.ts)
//   RepairHandlers.cpp   every other handler                (*-handler.ts)
//   RepairInternal.*     UTF-8, JS character classes, scans (utils.ts, code-block-utils.ts)
//
// The block-level streaming filter (table / code block / block math modes,
// today in the platform-specific StreamingMarkdownFilter implementations) is
// not part of this module yet; see docs/MARKDOWN_REPAIR_PLAN.mdx, phase 2.
//
// All text is UTF-8. Positions are byte offsets.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace Markdown {

enum class LinkMode { Protocol, TextOnly };

// Same names and defaults as the reference's options object.
struct RepairOptions {
  bool bold = true;
  bool boldItalic = true;
  bool comparisonOperators = true;
  bool htmlTags = true;
  bool images = true;
  bool inlineCode = true;
  bool inlineKatex = false;  // opt-in upstream too: `$` is ambiguous with currency
  bool italic = true;
  bool katex = true;
  bool links = true;
  bool setextHeadings = true;
  bool singleTilde = true;
  bool strikethrough = true;
  LinkMode linkMode = LinkMode::Protocol;
};

// Equivalent to the reference's top-level function.
std::string repairInlineMarkdown(std::string_view markdown, const RepairOptions &options);
void repairInlineMarkdownInPlace(std::string &markdown, const RepairOptions &options);

// Placeholder URL substituted for an incomplete link in LinkMode::Protocol.
// Renderers must treat links with this URL as inert.
inline constexpr std::string_view kIncompleteLinkUrl = "streamdown:incomplete-link";

// Sentinel for "no character here" in the code point helpers below.
inline constexpr uint32_t kNoCodePoint = 0xFFFFFFFFu;

// Helpers with the same semantics as the reference's public exports.
bool isWordChar(uint32_t codePoint);
bool isWithinCodeBlock(std::string_view text, size_t position);
bool isWithinMathBlock(std::string_view text, size_t position);
bool isWithinLinkOrImageUrl(std::string_view text, size_t position);

}  // namespace Markdown

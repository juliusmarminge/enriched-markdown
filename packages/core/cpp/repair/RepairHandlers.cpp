// Counterpart of the reference's single-purpose handler files: single-tilde-handler.ts,
// comparison-operator-handler.ts, html-tag-handler.ts,
// setext-heading-handler.ts, link-image-handler.ts, inline-code-handler.ts,
// strikethrough-handler.ts and katex-handler.ts. Emphasis lives in
// RepairEmphasis.cpp.
#include "RepairInternal.hpp"

namespace Markdown::RepairHandlers {

using namespace RepairInternal;

// /([\p{L}\p{N}_])~(?!~)(?=[\p{L}\p{N}_])/gu  ->  "$1\~"
// A lone ~ between word characters is not strikethrough; escape it so the
// parser does not treat `20~25` as a delimiter.
void singleTilde(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  if (text.find('~') == npos) {
    return;
  }
  std::string out;
  size_t copied = 0;
  bool changed = false;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] != '~' || (i + 1 < text.size() && text[i + 1] == '~')) {
      continue;
    }
    if (!isWordChar(codePointBefore(text, i)) || !isWordChar(codePointAt(text, i + 1)) || ctx.code().inside(i)) {
      continue;
    }
    out.append(text.substr(copied, i - copied));
    out.push_back('\\');
    copied = i;
    changed = true;
  }
  if (!changed) {
    return;
  }
  out.append(text.substr(copied));
  ctx.assign(std::move(out));
}

// /^(\s*(?:[-*+]|\d+[.)]) +)>(=?\s*[$]?\d)/gm  ->  "$1\>$2"
// `- > 25` is a comparison in a list item, not a blockquote.
void comparisonOperators(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  if (text.find('>') == npos) {
    return;
  }
  const size_t n = text.size();

  // `^` with the m flag matches after \n, \r, U+2028 and U+2029.
  auto isLineStart = [&](size_t s) {
    if (s == 0) {
      return true;
    }
    const char c = text[s - 1];
    if (c == '\n' || c == '\r') {
      return true;
    }
    return s >= 3 && static_cast<unsigned char>(text[s - 3]) == 0xE2 &&
           static_cast<unsigned char>(text[s - 2]) == 0x80 &&
           (static_cast<unsigned char>(text[s - 1]) == 0xA8 || static_cast<unsigned char>(text[s - 1]) == 0xA9);
  };
  auto skipJsWhitespace = [&](size_t i) {
    while (i < n) {
      const auto [codePoint, length] = decodeAt(text, i);
      if (!isJsWhitespace(codePoint)) {
        break;
      }
      i += length;
    }
    return i;
  };
  // Returns the index of `>` on a match starting at s, and sets matchEnd.
  // Every piece of the pattern is disjoint from its neighbour, so a greedy
  // scan without backtracking finds exactly what the regex finds.
  auto tryMatch = [&](size_t s, size_t &matchEnd) -> size_t {
    size_t i = skipJsWhitespace(s);
    if (i >= n) {
      return npos;
    }
    if (text[i] == '-' || text[i] == '*' || text[i] == '+') {
      ++i;
    } else if (isAsciiDigit(text[i])) {
      while (i < n && isAsciiDigit(text[i])) {
        ++i;
      }
      if (i >= n || (text[i] != '.' && text[i] != ')')) {
        return npos;
      }
      ++i;
    } else {
      return npos;
    }
    if (i >= n || text[i] != ' ') {
      return npos;
    }
    while (i < n && text[i] == ' ') {
      ++i;
    }
    if (i >= n || text[i] != '>') {
      return npos;
    }
    const size_t gt = i++;
    if (i < n && text[i] == '=') {
      ++i;
    }
    i = skipJsWhitespace(i);
    if (i < n && text[i] == '$') {
      ++i;
    }
    if (i >= n || !isAsciiDigit(text[i])) {
      return npos;
    }
    matchEnd = i + 1;
    return gt;
  };

  std::string out;
  size_t copied = 0;
  bool changed = false;
  for (size_t s = 0; s < n; ++s) {
    if (!isLineStart(s)) {
      continue;
    }
    size_t matchEnd = 0;
    const size_t gt = tryMatch(s, matchEnd);
    if (gt == npos) {
      continue;
    }
    if (!ctx.code().inside(s)) {
      out.append(text.substr(copied, gt - copied));
      out.push_back('\\');
      copied = gt;
      changed = true;
    }
    s = matchEnd - 1; // loop increment moves to matchEnd
  }
  if (!changed) {
    return;
  }
  out.append(text.substr(copied));
  ctx.assign(std::move(out));
}

// /<[a-zA-Z/][^>]*$/  ->  strip it and trimEnd
// An unterminated tag at the end would otherwise swallow following text.
void htmlTags(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  const size_t lastGt = text.rfind('>');
  for (size_t p = lastGt == npos ? 0 : lastGt + 1; p + 1 < text.size(); ++p) {
    if (text[p] != '<' || !isAsciiLetterOrSlash(text[p + 1])) {
      continue;
    }
    if (!ctx.code().inside(p)) {
      ctx.erase(jsTrimEnd(text.substr(0, p)).size());
    }
    return;
  }
}

// A trailing lone `-`, `--`, `=` or `==` line under text would turn that text
// into a setext heading for a moment. A zero-width space breaks the pattern
// without being visible.
void setextHeadings(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  const size_t lastNewline = text.rfind('\n');
  if (lastNewline == npos) {
    return;
  }
  const std::string_view lastLine = text.substr(lastNewline + 1);
  const std::string_view previous = text.substr(0, lastNewline);
  const std::string_view trimmed = jsTrim(lastLine);

  // /^c{1,2}$/ on the trimmed line
  auto isOnly = [&](char c) { return !trimmed.empty() && trimmed.size() <= 2 && trimmed.find_first_not_of(c) == npos; };
  // /^[\s]*c{1,2}[\s]+$/ on the raw line: trailing whitespace already breaks the underline
  auto hasTrailingSpace = [&](char c) {
    std::string_view rest = jsTrimStart(lastLine);
    size_t run = 0;
    while (!rest.empty() && rest[0] == c && run < 2) {
      rest.remove_prefix(1);
      ++run;
    }
    return run > 0 && !rest.empty() && jsTrimStart(rest).empty();
  };
  auto previousLineHasContent = [&]() {
    const size_t newline = previous.rfind('\n');
    return !jsTrim(newline == npos ? previous : previous.substr(newline + 1)).empty();
  };

  for (const char c : {'-', '='}) {
    if (isOnly(c) && !hasTrailingSpace(c) && previousLineHasContent()) {
      ctx.append(kZeroWidthSpace);
      return;
    }
  }
}

namespace {

// findFirstIncompleteBracket(): in text-only mode the bracket to drop is the
// first unmatched `[`, skipping complete links.
size_t findFirstIncompleteBracket(std::string_view text, size_t maxPos, const CodeLookup &code) {
  for (size_t j = 0; j < maxPos; ++j) {
    if (text[j] != '[' || code.inside(j) || (j > 0 && text[j - 1] == '!')) {
      continue;
    }
    const size_t closing = findMatchingClosingBracket(text, j);
    if (closing == npos) {
      return j;
    }
    if (closing + 1 < text.size() && text[closing + 1] == '(') {
      const size_t urlEnd = text.find(')', closing + 2);
      if (urlEnd != npos) {
        j = urlEnd;
      }
    }
  }
  return maxPos;
}

} // namespace

// Incomplete images are removed (nothing sensible to show); incomplete links
// keep their text and get a placeholder URL, or lose their brackets in
// text-only mode.
void links(RepairContext &ctx, LinkMode mode) {
  const std::string_view text = ctx.text();

  // handleIncompleteUrl(): [text](partial-url
  const size_t lastParen = text.rfind("](");
  if (lastParen != npos && !ctx.code().inside(lastParen) && text.find(')', lastParen + 2) == npos) {
    const size_t open = findMatchingOpeningBracket(text, lastParen);
    if (open != npos && !ctx.code().inside(open)) {
      const bool isImage = open > 0 && text[open - 1] == '!';
      if (isImage) {
        ctx.erase(open - 1);
        return;
      }
      // text[open, lastParen + 2) is "[link text](" ; drop the partial URL after it.
      ctx.erase(lastParen + 2);
      if (mode == LinkMode::TextOnly) {
        ctx.erase(lastParen, 2); // the "]("
        ctx.erase(open, 1);      // the "["
      } else {
        ctx.append(kIncompleteLinkUrl);
        ctx.append(')');
      }
      return;
    }
  }

  // handleIncompleteText(): [partial-text without a closing ]
  for (size_t i = text.size(); i > 0; --i) {
    const size_t idx = i - 1;
    if (text[idx] != '[' || ctx.code().inside(idx) || findMatchingClosingBracket(text, idx) != npos) {
      continue;
    }
    if (idx > 0 && text[idx - 1] == '!') {
      ctx.erase(idx - 1);
    } else if (mode == LinkMode::TextOnly) {
      ctx.erase(findFirstIncompleteBracket(text, idx, ctx.code()), 1);
    } else {
      ctx.append(kIncompleteLinkSuffix);
    }
    return;
  }
}

// /(`)([^`]*?)$/ , with the single-line ```code`` case handled first
void inlineCode(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  // handleInlineTripleBackticks(): /^```[^`\n]*```?$/
  if (startsWith(text, "```") && text.size() >= 5 && endsWith(text, "``") && text.find('\n') == npos) {
    const size_t closerLength = endsWith(text, "```") ? 3 : 2;
    if (text.substr(3, text.size() - 3 - closerLength).find('`') == npos) {
      if (closerLength == 2) {
        ctx.append('`');
      }
      return;
    }
  }
  const size_t lastTick = text.rfind('`');
  if (lastTick == npos || countNonOverlapping(text, "```") % 2 == 1) { // isInsideIncompleteCodeBlock()
    return;
  }
  const std::string_view content = text.substr(lastTick + 1);
  if (content.empty() || isWhitespaceOrMarkersOnly(content)) {
    return;
  }
  if (countSingleBackticks(text) % 2 == 1) {
    ctx.append('`');
  }
}

// /(~~)([^~]*?)$/ plus the half-closed /(~~)([^~]+)~$/ case
void strikethrough(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  if (const auto content = matchTrailingMarker(text, "~~", '~', false)) {
    if (content->empty() || isWhitespaceOrMarkersOnly(*content) || ctx.insideAnyCode(text.rfind("~~"))) {
      return;
    }
    if (countNonOverlapping(text, "~~") % 2 == 1) {
      ctx.append("~~");
    }
    return;
  }
  // ~~content~ -> ~~content~~
  if (matchHalfCompleteMarker(text, "~~", '~') && !ctx.insideAnyCode(text.rfind("~~")) &&
      countNonOverlapping(text, "~~") % 2 == 1) {
    ctx.append('~');
  }
}

// Closes an open $$ block. Multi-line blocks get the closer on its own line.
void katex(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  // countDollarPairs()
  size_t pairs = 0;
  bool inInline = false;
  for (size_t i = 0; i + 1 < text.size(); ++i) {
    if (text[i] == '`' && !isPartOfTriple(text, i)) {
      inInline = !inInline;
    }
    if (!inInline && text[i] == '$' && text[i + 1] == '$') {
      ++pairs;
      ++i;
    }
  }
  if (pairs % 2 == 0) {
    return;
  }
  // addClosingKatex()
  if (endsWith(text, "$") && !endsWith(text, "$$")) { // half of the closer already streamed
    ctx.append('$');
    return;
  }
  const size_t firstDollar = text.find("$$");
  const bool multiLine = firstDollar != npos && text.find('\n', firstDollar) != npos;
  ctx.append(multiLine && !endsWith(text, "\n") ? "\n$$" : "$$");
}

// Closes an open $…$ span. Opt-in, because `$5 and $6` is not math.
void inlineKatex(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  // countSingleDollars()
  size_t count = 0;
  bool inInline = false;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] == '\\') {
      ++i;
      continue;
    }
    if (text[i] == '`' && !isPartOfTriple(text, i)) {
      inInline = !inInline;
      continue;
    }
    if (!inInline && text[i] == '$') {
      if (i + 1 < text.size() && text[i + 1] == '$') {
        ++i;
      } else {
        ++count;
      }
    }
  }
  if (count % 2 == 1) {
    ctx.append('$');
  }
}

} // namespace Markdown::RepairHandlers

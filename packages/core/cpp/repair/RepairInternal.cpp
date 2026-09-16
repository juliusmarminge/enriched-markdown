// Counterpart of the reference's utils.ts and code-block-utils.ts.
// Attribution is in MarkdownRepair.hpp.
#include "RepairInternal.hpp"

#include <algorithm>

namespace Markdown::RepairInternal {

// --- UTF-8 -----------------------------------------------------------------

namespace {
constexpr uint32_t kReplacementChar = 0xFFFD; // what malformed UTF-8 decodes to
}

Decoded decodeAt(std::string_view text, size_t i) {
  const auto lead = static_cast<unsigned char>(text[i]);
  if (lead < 0x80) {
    return {lead, 1};
  }
  size_t length = 0;
  uint32_t codePoint = 0;
  if ((lead & 0xE0) == 0xC0) {
    length = 2;
    codePoint = lead & 0x1F;
  } else if ((lead & 0xF0) == 0xE0) {
    length = 3;
    codePoint = lead & 0x0F;
  } else if ((lead & 0xF8) == 0xF0) {
    length = 4;
    codePoint = lead & 0x07;
  } else {
    return {kReplacementChar, 1}; // stray continuation or invalid lead byte
  }
  if (i + length > text.size()) {
    return {kReplacementChar, 1};
  }
  for (size_t k = 1; k < length; ++k) {
    const auto c = static_cast<unsigned char>(text[i + k]);
    if ((c & 0xC0) != 0x80) {
      return {kReplacementChar, 1};
    }
    codePoint = (codePoint << 6) | (c & 0x3F);
  }
  return {codePoint, length};
}

uint32_t codePointAt(std::string_view text, size_t i) {
  return i < text.size() ? decodeAt(text, i).codePoint : kNoCodePoint;
}

size_t codePointStartBefore(std::string_view text, size_t i) {
  size_t j = i - 1;
  size_t steps = 0;
  while (j > 0 && steps < 3 && (static_cast<unsigned char>(text[j]) & 0xC0) == 0x80) {
    --j;
    ++steps;
  }
  return j;
}

uint32_t codePointBefore(std::string_view text, size_t i) {
  if (i == 0) {
    return kNoCodePoint;
  }
  const size_t start = codePointStartBefore(text, i);
  const Decoded d = decodeAt(text, start);
  return start + d.length == i ? d.codePoint : kReplacementChar;
}

// --- JS character classes --------------------------------------------------

bool isWordCharUnit(uint32_t codePoint) {
  return codePoint <= 0xFFFF && isWordChar(codePoint);
}

bool isJsWhitespace(uint32_t codePoint) {
  switch (codePoint) {
    case 0x09:
    case 0x0A:
    case 0x0B:
    case 0x0C:
    case 0x0D:
    case 0x20:
    case 0xA0:
    case 0x1680:
    case 0x2028:
    case 0x2029:
    case 0x202F:
    case 0x205F:
    case 0x3000:
    case 0xFEFF:
      return true;
    default:
      return codePoint >= 0x2000 && codePoint <= 0x200A;
  }
}

bool isSpaceTabNewline(uint32_t codePoint) {
  return codePoint == ' ' || codePoint == '\t' || codePoint == '\n';
}

bool isAsciiDigit(char c) {
  return c >= '0' && c <= '9';
}

bool isAsciiLetterOrSlash(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '/';
}

std::string_view jsTrimStart(std::string_view text) {
  size_t i = 0;
  while (i < text.size()) {
    const Decoded d = decodeAt(text, i);
    if (!isJsWhitespace(d.codePoint)) {
      break;
    }
    i += d.length;
  }
  return text.substr(i);
}

std::string_view jsTrimEnd(std::string_view text) {
  size_t end = text.size();
  while (end > 0 && isJsWhitespace(codePointBefore(text, end))) {
    end = codePointStartBefore(text, end);
  }
  return text.substr(0, end);
}

std::string_view jsTrim(std::string_view text) {
  return jsTrimEnd(jsTrimStart(text));
}

bool isWhitespaceOrMarkersOnly(std::string_view text) {
  size_t i = 0;
  while (i < text.size()) {
    const auto [codePoint, length] = decodeAt(text, i);
    if (!(isJsWhitespace(codePoint) || codePoint == '_' || codePoint == '~' || codePoint == '*' || codePoint == '`')) {
      return false;
    }
    i += length;
  }
  return true;
}

bool isListItemMarkerLine(std::string_view line) {
  std::string_view rest = jsTrimStart(line);
  if (rest.empty() || (rest[0] != '-' && rest[0] != '*' && rest[0] != '+')) {
    return false;
  }
  rest.remove_prefix(1);
  return !rest.empty() && jsTrimStart(rest).empty();
}

// --- Plain string helpers --------------------------------------------------

bool startsWith(std::string_view text, std::string_view prefix) {
  return text.size() >= prefix.size() && text.substr(0, prefix.size()) == prefix;
}

bool endsWith(std::string_view text, std::string_view suffix) {
  return text.size() >= suffix.size() && text.substr(text.size() - suffix.size()) == suffix;
}

bool isTripleAt(std::string_view text, size_t i) {
  return i + 3 <= text.size() && text[i] == '`' && text[i + 1] == '`' && text[i + 2] == '`';
}

size_t countNonOverlapping(std::string_view text, std::string_view needle) {
  size_t count = 0;
  for (size_t pos = text.find(needle); pos != npos; pos = text.find(needle, pos + needle.size())) {
    ++count;
  }
  return count;
}

std::string_view lineBefore(std::string_view text, size_t index) {
  const size_t newline = text.substr(0, index).rfind('\n');
  const size_t lineStart = newline == npos ? 0 : newline + 1;
  return text.substr(lineStart, index - lineStart);
}

// --- Regex stand-ins -------------------------------------------------------

// Every `c` before the marker's end must be inside the marker itself, so the
// marker can only start at lastC + 1 - len or, when it overlaps the allowed
// trailing `c`, one position later. The loop therefore runs at most a couple
// of iterations; it is written as a scan only to keep it obviously correct.
std::optional<std::string_view> matchTrailingMarker(std::string_view text, std::string_view marker, char c,
                                                    bool allowTrailingSingle) {
  const size_t n = text.size();
  const size_t len = marker.size();
  if (n < len) {
    return std::nullopt;
  }
  const size_t cleanEnd = (allowTrailingSingle && n > 0 && text[n - 1] == c) ? n - 1 : n;
  const size_t lastC = text.substr(0, cleanEnd).rfind(c);
  size_t p = (lastC != npos && lastC + 1 > len) ? lastC + 1 - len : 0;
  for (; p + len <= n; ++p) {
    if (text.substr(p, len) == marker) {
      return text.substr(p + len);
    }
  }
  return std::nullopt;
}

bool matchHalfCompleteMarker(std::string_view text, std::string_view marker, char c) {
  const size_t n = text.size();
  const size_t len = marker.size();
  if (n < len + 2 || text[n - 1] != c) {
    return false;
  }
  const size_t lastC = text.substr(0, n - 1).rfind(c);
  size_t p = (lastC != npos && lastC + 1 > len) ? lastC + 1 - len : 0;
  for (; p + len + 1 < n; ++p) { // leaves >= 1 char between marker and final c
    if (text.substr(p, len) == marker) {
      return true;
    }
  }
  return false;
}

// --- Context lookups -------------------------------------------------------

// buildCodeBlockLookup()
CodeLookup::CodeLookup(std::string_view text) : insideAt_(text.size() + 1, 0) {
  const size_t n = text.size();
  bool inInline = false;
  bool inFence = false;
  size_t i = 0;
  while (i < n) {
    if (text[i] == '\\' && i + 1 < n && text[i + 1] == '`') {
      const uint8_t state = (inInline || inFence) ? 1 : 0;
      insideAt_[i + 1] = state;
      insideAt_[i + 2] = state;
      i += 2;
      continue;
    }
    if (isTripleAt(text, i)) {
      inFence = !inFence;
      const uint8_t state = (inInline || inFence) ? 1 : 0;
      for (size_t p = i + 1; p <= i + 3; ++p) {
        insideAt_[p] = state;
      }
      i += 3;
      continue;
    }
    if (!inFence && text[i] == '`') {
      inInline = !inInline;
    }
    insideAt_[i + 1] = (inInline || inFence) ? 1 : 0;
    ++i;
  }
}

bool CodeLookup::inside(size_t position) const {
  return insideAt_[std::min(position, insideAt_.size() - 1)] != 0;
}

// isWithinMathBlock(), evaluated once for every position.
MathLookup::MathLookup(std::string_view text)
    : hasDelimiters_(text.find('$') != npos || text.find("\\(") != npos || text.find("\\[") != npos) {
  if (!hasDelimiters_) {
    return;
  }
  enum class Context : uint8_t { None, InlineDollar, BlockDollar, InlineLatex, BlockLatex };
  const size_t n = text.size();
  insideAt_.assign(n + 1, 0);
  Context ctx = Context::None;
  auto mark = [&](size_t from, size_t to) {
    const uint8_t state = ctx != Context::None ? 1 : 0;
    for (size_t p = from; p <= to && p <= n; ++p) {
      insideAt_[p] = state;
    }
  };
  size_t i = 0;
  while (i < n) {
    const char c = text[i];
    const char next = i + 1 < n ? text[i + 1] : '\0';
    if (c == '\\' && next == '$') { // escaped dollar
      mark(i + 1, i + 2);
      i += 2;
      continue;
    }
    if (c == '\\') {
      // getLatexMathContext(): only these four transitions consume the pair
      bool handled = true;
      if (next == '[' && ctx == Context::None) {
        ctx = Context::BlockLatex;
      } else if (next == ']' && ctx == Context::BlockLatex) {
        ctx = Context::None;
      } else if (next == '(' && ctx == Context::None) {
        ctx = Context::InlineLatex;
      } else if (next == ')' && ctx == Context::InlineLatex) {
        ctx = Context::None;
      } else {
        handled = false;
      }
      if (handled) {
        mark(i + 1, i + 2);
        i += 2;
        continue;
      }
    }
    if (c == '$' && ctx != Context::InlineLatex && ctx != Context::BlockLatex) {
      if (next == '$') {
        ctx = ctx == Context::BlockDollar ? Context::None : Context::BlockDollar;
        mark(i + 1, i + 2);
        i += 2;
        continue;
      }
      if (ctx != Context::BlockDollar) {
        ctx = ctx == Context::InlineDollar ? Context::None : Context::InlineDollar;
      }
    }
    mark(i + 1, i + 1);
    ++i;
  }
}

bool MathLookup::inside(size_t position) const {
  return hasDelimiters_ && insideAt_[std::min(position, insideAt_.size() - 1)] != 0;
}

CompleteInlineCodeLookup::CompleteInlineCodeLookup(std::string_view text) : insideAt_(text.size() + 1, 0) {
  const size_t n = text.size();
  bool inFence = false;
  size_t spanStart = npos;
  for (size_t i = 0; i < n; ++i) {
    if (text[i] == '\\' && i + 1 < n && text[i + 1] == '`') {
      ++i;
      continue;
    }
    if (isTripleAt(text, i)) {
      inFence = !inFence;
      i += 2;
      continue;
    }
    if (inFence || text[i] != '`') {
      continue;
    }
    if (spanStart == npos) {
      spanStart = i;
      continue;
    }
    for (size_t p = spanStart + 1; p < i; ++p) { // strictly between the backticks
      insideAt_[p] = 1;
    }
    spanStart = npos;
  }
}

bool CompleteInlineCodeLookup::inside(size_t position) const {
  return position < insideAt_.size() && insideAt_[position] != 0;
}

const CodeLookup &RepairContext::code() {
  if (!code_) {
    code_.emplace(text_);
  }
  return *code_;
}

const MathLookup &RepairContext::math() {
  if (!math_) {
    math_.emplace(text_);
  }
  return *math_;
}

bool RepairContext::insideAnyCode(size_t position) {
  if (code().inside(position)) {
    return true;
  }
  if (!completeInline_) {
    completeInline_.emplace(text_);
  }
  return completeInline_->inside(position);
}

void RepairContext::append(std::string_view suffix) {
  text_.append(suffix);
  invalidate();
}

void RepairContext::append(char c) {
  text_.push_back(c);
  invalidate();
}

void RepairContext::insert(size_t position, char c) {
  text_.insert(position, 1, c);
  invalidate();
}

void RepairContext::erase(size_t position, size_t count) {
  text_.erase(position, count);
  invalidate();
}

void RepairContext::assign(std::string &&replacement) {
  text_ = std::move(replacement);
  invalidate();
}

void RepairContext::invalidate() {
  code_.reset();
  math_.reset();
  completeInline_.reset();
}

bool isWithinHtmlTag(std::string_view text, size_t position) {
  for (size_t i = position; i > 0; --i) {
    const char c = text[i - 1];
    if (c == '>' || c == '\n') {
      return false;
    }
    if (c == '<') {
      return i < text.size() && isAsciiLetterOrSlash(text[i]);
    }
  }
  return false;
}

bool isHorizontalRule(std::string_view text, size_t markerIndex, char marker) {
  const size_t before = text.substr(0, markerIndex).rfind('\n');
  const size_t lineStart = before == npos ? 0 : before + 1;
  const size_t after = text.find('\n', markerIndex);
  const size_t lineEnd = after == npos ? text.size() : after;
  size_t markerCount = 0;
  for (size_t i = lineStart; i < lineEnd; ++i) {
    const char c = text[i];
    if (c == marker) {
      ++markerCount;
    } else if (c != ' ' && c != '\t') {
      return false;
    }
  }
  return markerCount >= 3;
}

bool isPartOfTriple(std::string_view text, size_t i) {
  return isTripleAt(text, i) || (i >= 1 && isTripleAt(text, i - 1)) || (i >= 2 && isTripleAt(text, i - 2));
}

size_t countSingleBackticks(std::string_view text) {
  size_t count = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] == '\\' && i + 1 < text.size() && text[i + 1] == '`') {
      ++i;
      continue;
    }
    if (text[i] == '`' && !isPartOfTriple(text, i)) {
      ++count;
    }
  }
  return count;
}

size_t findMatchingOpeningBracket(std::string_view text, size_t closeIndex) {
  size_t depth = 1;
  for (size_t i = closeIndex; i > 0; --i) {
    const char c = text[i - 1];
    if (c == ']') {
      ++depth;
    } else if (c == '[' && --depth == 0) {
      return i - 1;
    }
  }
  return npos;
}

size_t findMatchingClosingBracket(std::string_view text, size_t openIndex) {
  size_t depth = 1;
  for (size_t i = openIndex + 1; i < text.size(); ++i) {
    if (text[i] == '[') {
      ++depth;
    } else if (text[i] == ']' && --depth == 0) {
      return i;
    }
  }
  return npos;
}

} // namespace Markdown::RepairInternal

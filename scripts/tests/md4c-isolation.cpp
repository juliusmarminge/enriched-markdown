#include "md4c/md4c.h"
#include "parser/MD4CParser.hpp"
#include <cassert>
#include <initializer_list>
#include <string>

// Keep Enriched's entry point before declaring the other copy's original name.
static auto enrichedParse = md_parse;
#undef md_parse
extern "C" int md_parse(const MD_CHAR *, MD_SIZE, const MD_PARSER *, void *);

struct ParseResult {
  int strongSpans = 0;
  std::string text;
};

int main() {
  assert(enrichedParse != md_parse);

  MD_PARSER callbacks = {};
  callbacks.enter_block = [](MD_BLOCKTYPE, void *, void *) { return 0; };
  callbacks.leave_block = [](MD_BLOCKTYPE, void *, void *) { return 0; };
  callbacks.enter_span = [](MD_SPANTYPE type, void *, void *userdata) {
    if (type == MD_SPAN_STRONG) {
      static_cast<ParseResult *>(userdata)->strongSpans++;
    }
    return 0;
  };
  callbacks.leave_span = [](MD_SPANTYPE, void *, void *) { return 0; };
  callbacks.text = [](MD_TEXTTYPE, const MD_CHAR *text, MD_SIZE size, void *userdata) {
    static_cast<ParseResult *>(userdata)->text.append(text, size);
    return 0;
  };

  const std::string markdown = "**bold**";
  for (auto parse : {enrichedParse, md_parse}) {
    ParseResult result;
    assert(parse(markdown.c_str(), static_cast<MD_SIZE>(markdown.size()), &callbacks, &result) == 0);
    assert(result.strongSpans == 1);
    assert(result.text == "bold");
  }

  Markdown::MD4CParser parser;
  auto root = parser.parse(markdown);
  assert(root && root->type == Markdown::NodeType::Document);
  assert(root->children.size() == 1);
  auto paragraph = root->children.front();
  assert(paragraph->type == Markdown::NodeType::Paragraph);
  assert(paragraph->children.size() == 1);
  auto strong = paragraph->children.front();
  assert(strong->type == Markdown::NodeType::Strong);
  assert(strong->children.size() == 1);
  assert(strong->children.front()->type == Markdown::NodeType::Text);
  assert(strong->children.front()->content == "bold");
}

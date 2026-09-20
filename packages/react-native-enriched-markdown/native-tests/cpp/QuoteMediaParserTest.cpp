#include "MD4CParser.hpp"
#include <cassert>

// Compile with core MD4CParser.cpp + md4c.c; no platform image/player module.
int main() {
  Markdown::MD4CParser parser;
  auto root = parser.parse(
      "> ![first](same \"First\")\n>\n> > ![nested](same)\n> >\n> > <video src=\"movie\" title=\"Movie\"></video>\n");
  assert(root && root->children.size() == 1);
  auto outer = root->children[0];
  assert(outer->type == Markdown::NodeType::Blockquote && outer->children.size() == 2);
  auto imageParagraph = outer->children[0];
  assert(imageParagraph->type == Markdown::NodeType::Paragraph && imageParagraph->children.size() == 1);
  auto image = imageParagraph->children[0];
  assert(image->type == Markdown::NodeType::Image);
  assert(image->attributes.at("url") == "same" && image->attributes.at("title") == "First");
  auto inner = outer->children[1];
  assert(inner->type == Markdown::NodeType::Blockquote && inner->children.size() == 2);
  assert(inner->children[0]->type == Markdown::NodeType::Paragraph);
  assert(inner->children[0]->children.size() == 1);
  assert(inner->children[0]->children[0]->type == Markdown::NodeType::Image);
  assert(inner->children[0]->children[0]->attributes.at("url") == "same");
  auto video = inner->children[1];
  assert(video->type == Markdown::NodeType::Video);
  assert(video->attributes.at("url") == "movie");
}

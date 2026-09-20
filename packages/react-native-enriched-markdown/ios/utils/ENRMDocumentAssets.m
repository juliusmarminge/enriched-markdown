#import "ENRMDocumentAssets.h"

static NSString *ENRMAssetText(MarkdownASTNode *node)
{
  NSMutableString *text = [NSMutableString stringWithString:node.content ?: @""];
  for (MarkdownASTNode *child in node.children)
    [text appendString:ENRMAssetText(child)];
  return text;
}

static void ENRMVisitAssets(MarkdownASTNode *node, MarkdownASTNode *parent, MarkdownASTNode *root, NSString *placement,
                            NSString *anchor, NSMutableArray *assets)
{
  if (node.type == MarkdownNodeTypeTable)
    placement = @"table";
  else if (node.type == MarkdownNodeTypeOrderedList || node.type == MarkdownNodeTypeUnorderedList)
    placement = @"list";
  else if (node.type == MarkdownNodeTypeBlockquote || node.type == MarkdownNodeTypeAdmonition)
    placement = @"blockquote";

  BOOL isImage = node.type == MarkdownNodeTypeImage;
  BOOL isVideo = node.type == MarkdownNodeTypeVideo;
  if (isImage || isVideo || node.type == MarkdownNodeTypeLink) {
    BOOL blockImage = isImage && parent.type == MarkdownNodeTypeParagraph && parent.children.count == 1 &&
                      [root.children containsObject:parent];
    BOOL eligible = blockImage || (isVideo && parent == root);
    NSString *identifier = [NSString stringWithFormat:@"asset-%lu", (unsigned long)assets.count];
    NSString *assetPlacement = eligible ? @"block" : placement;
    NSString *assetAnchor =
        blockImage ? [anchor substringToIndex:[anchor rangeOfString:@"." options:NSBackwardsSearch].location] : anchor;
    NSString *kind = isImage ? @"image" : (isVideo ? @"video" : @"link");
    NSString *url = node.attributes[@"url"] ?: @"";
    [assets addObject:@{
      @"id" : identifier,
      @"kind" : kind,
      @"url" : url,
      @"anchor" : assetAnchor,
      @"altText" :
          [ENRMAssetText(node) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],
      @"title" : node.attributes[@"title"] ?: @"",
      @"placement" : assetPlacement,
      @"eligible" : @(eligible)
    }];
  }
  [node.children enumerateObjectsUsingBlock:^(MarkdownASTNode *child, NSUInteger index, BOOL *stop) {
    NSString *childAnchor = anchor.length > 0 ? [anchor stringByAppendingFormat:@".%lu", (unsigned long)index]
                                              : [NSString stringWithFormat:@"%lu", (unsigned long)index];
    ENRMVisitAssets(child, node, root, placement, childAnchor, assets);
  }];
}

NSArray<NSDictionary *> *ENRMPrepareDocumentAssets(MarkdownASTNode *ast)
{
  NSMutableArray *assets = [NSMutableArray array];
  ENRMVisitAssets(ast, nil, ast, @"inline", @"0", assets);
  return assets;
}

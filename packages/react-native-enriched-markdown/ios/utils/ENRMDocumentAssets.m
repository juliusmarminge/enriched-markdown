#import "ENRMDocumentAssets.h"
#import <math.h>

static NSString *ENRMAssetText(MarkdownASTNode *node)
{
  NSMutableString *text = [NSMutableString stringWithString:node.content ?: @""];
  for (MarkdownASTNode *child in node.children)
    [text appendString:ENRMAssetText(child)];
  return text;
}

static void ENRMVisitAssets(MarkdownASTNode *node, MarkdownASTNode *parent, MarkdownASTNode *root, NSString *placement,
                            NSString *anchor, NSMutableArray *assets, BOOL enableSlots, BOOL decisionsAccepted,
                            NSDictionary *overrides)
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
    NSDictionary *override = overrides[identifier];
    if (eligible && enableSlots && (!decisionsAccepted || override)) {
      MarkdownASTNode *slot = blockImage ? parent : node;
      slot.attributes[@"_enrmMediaSlot"] = identifier;
      slot.attributes[@"_enrmMediaKind"] = isVideo ? @"video" : @"image";
      BOOL matchesIdentity = override && [override[@"url"] isEqualToString:url] &&
                             [override[@"kind"] isEqualToString:kind] &&
                             [override[@"anchor"] isEqualToString:assetAnchor];
      // JS carries overrides only across safe trailing appends. The accepted
      // native parse still verifies occurrence identity before using its height.
      if (matchesIdentity) {
        slot.attributes[@"_enrmMediaHeight"] = [override[@"height"] stringValue];
        slot.attributes[@"_enrmMediaWidth"] = [override[@"width"] stringValue];
      }
    }
  }
  [node.children enumerateObjectsUsingBlock:^(MarkdownASTNode *child, NSUInteger index, BOOL *stop) {
    NSString *childAnchor = anchor.length > 0 ? [anchor stringByAppendingFormat:@".%lu", (unsigned long)index]
                                              : [NSString stringWithFormat:@"%lu", (unsigned long)index];
    ENRMVisitAssets(child, node, root, placement, childAnchor, assets, enableSlots, decisionsAccepted, overrides);
  }];
}

NSArray<NSDictionary *> *ENRMPrepareDocumentAssets(MarkdownASTNode *ast, BOOL enableMediaSlots, BOOL decisionsAccepted,
                                                   NSDictionary *overrides)
{
  NSMutableArray *assets = [NSMutableArray array];
  ENRMVisitAssets(ast, nil, ast, @"inline", @"0", assets, enableMediaSlots, decisionsAccepted, overrides);
  return assets;
}

CGFloat ENRMMediaSlotHeight(MarkdownASTNode *node, CGFloat width, StyleConfig *config)
{
  NSString *height = node.attributes[@"_enrmMediaHeight"];
  CGFloat measuredWidth = [node.attributes[@"_enrmMediaWidth"] doubleValue];
  if (height && (measuredWidth == 0 || fabs(measuredWidth - width) < 0.5))
    return MAX(0, height.doubleValue);
  if ([node.attributes[@"_enrmMediaKind"] isEqualToString:@"video"])
    return width / MAX(config.videoAspectRatio, 0.01);
  if (config.imageAspectRatio > 0)
    return width / config.imageAspectRatio;
  return config.imageMaxHeight > 0 ? config.imageMaxHeight : MAX(config.imageHeight, 1);
}

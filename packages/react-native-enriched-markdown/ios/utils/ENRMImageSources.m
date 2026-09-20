#import "ENRMImageSources.h"
#import <objc/runtime.h>

static char ENRMImageSourceDecisionKey;

NSDictionary *ENRMImageSourceDecisionForNode(MarkdownASTNode *node)
{
  return objc_getAssociatedObject(node, &ENRMImageSourceDecisionKey);
}

NSDictionary<NSString *, NSString *> *ENRMMergeImageRequestHeaders(NSDictionary *documentHeaders,
                                                                   NSDictionary *sourceHeaders)
{
  NSMutableDictionary *merged = [NSMutableDictionary dictionary];
  // Lowercase keys make overrides and cache identity independent of HTTP header casing.
  for (NSString *name in documentHeaders)
    merged[name.lowercaseString] = documentHeaders[name];
  for (NSString *name in sourceHeaders)
    merged[name.lowercaseString] = sourceHeaders[name];
  return merged;
}

static void ENRMVisitImageSources(MarkdownASTNode *node, NSArray<NSDictionary *> *assets, NSDictionary *sources,
                                  BOOL decisionsAccepted, NSUInteger *occurrence)
{
  // Match the accepted collector's image/video/link occurrence order. No source parse.
  if (node.type == MarkdownNodeTypeImage || node.type == MarkdownNodeTypeVideo || node.type == MarkdownNodeTypeLink) {
    NSUInteger index = (*occurrence)++;
    if (node.type == MarkdownNodeTypeImage) {
      NSDictionary *decision = @{@"pending" : @YES};
      NSDictionary *asset = index < assets.count ? assets[index] : nil;
      NSDictionary *source = asset ? sources[asset[@"id"]] : nil;
      BOOL matches =
          decisionsAccepted && [asset[@"kind"] isEqualToString:@"image"] &&
          [source[@"id"] isEqualToString:asset[@"id"]] && [asset[@"url"] isEqualToString:node.attributes[@"url"]] &&
          [source[@"url"] isEqualToString:asset[@"url"]] && [source[@"anchor"] isEqualToString:asset[@"anchor"]];
      if (matches && ([source[@"useDefault"] boolValue] || [source[@"uri"] length] > 0)) {
        decision = [source[@"useDefault"] boolValue]
                       ? @{@"pending" : @NO}
                       : @{@"pending" : @NO,
                           @"uri" : source[@"uri"],
                           @"headers" : source[@"headers"] ?: @{}};
      }
      objc_setAssociatedObject(node, &ENRMImageSourceDecisionKey, decision, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  }
  for (MarkdownASTNode *child in node.children)
    ENRMVisitImageSources(child, assets, sources, decisionsAccepted, occurrence);
}

static void ENRMClearImageSources(MarkdownASTNode *node)
{
  objc_setAssociatedObject(node, &ENRMImageSourceDecisionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  for (MarkdownASTNode *child in node.children)
    ENRMClearImageSources(child);
}

void ENRMPrepareImageSources(MarkdownASTNode *ast, NSArray<NSDictionary *> *assets, BOOL enabled,
                             BOOL decisionsAccepted, NSDictionary *sources)
{
  if (!enabled) {
    ENRMClearImageSources(ast);
    return;
  }
  NSUInteger occurrence = 0;
  ENRMVisitImageSources(ast, assets, sources, decisionsAccepted, &occurrence);
}

static uint64_t ENRMSourceMixUInt64(uint64_t hash, uint64_t value)
{
  for (NSUInteger i = 0; i < 8; i++) {
    hash ^= (uint8_t)(value & 0xFF);
    hash *= 1099511628211ULL;
    value >>= 8;
  }
  return hash;
}

static uint64_t ENRMSourceMixString(uint64_t hash, NSString *value)
{
  NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
  hash = ENRMSourceMixUInt64(hash, data.length);
  const uint8_t *bytes = data.bytes;
  for (NSUInteger i = 0; i < data.length; i++) {
    hash ^= bytes[i];
    hash *= 1099511628211ULL;
  }
  return hash;
}

uint64_t ENRMImageSourceSignatureForNode(MarkdownASTNode *node)
{
  NSDictionary *source = ENRMImageSourceDecisionForNode(node);
  uint64_t hash = 0;
  if (source) {
    hash = ENRMSourceMixUInt64(14695981039346656037ULL, [source[@"pending"] boolValue] ? 1 : 2);
    hash = ENRMSourceMixString(hash, source[@"uri"] ?: @"");
    NSDictionary *headers = ENRMMergeImageRequestHeaders(nil, source[@"headers"]);
    for (NSString *name in [headers.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
      hash = ENRMSourceMixString(hash, name);
      hash = ENRMSourceMixString(hash, headers[name]);
    }
  }
  uint64_t children = ENRMImageSourceSignatureForNodes(node.children);
  if (children)
    hash = ENRMSourceMixUInt64(hash ?: 14695981039346656037ULL, children);
  return hash;
}

uint64_t ENRMImageSourceSignatureForNodes(NSArray<MarkdownASTNode *> *nodes)
{
  uint64_t hash = 14695981039346656037ULL;
  BOOL hasSources = NO;
  for (MarkdownASTNode *node in nodes) {
    uint64_t source = ENRMImageSourceSignatureForNode(node);
    hasSources |= source != 0;
    hash = ENRMSourceMixUInt64(hash, source);
  }
  return hasSources ? hash : 0;
}

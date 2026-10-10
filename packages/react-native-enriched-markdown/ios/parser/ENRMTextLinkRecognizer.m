#import "ENRMTextLinkRecognizer.h"

ENRMLinkRegexConfig *ENRMCachedTextLinkRegexConfig(NSString *pattern, BOOL caseInsensitive, BOOL dotAll)
{
  static NSCache<NSString *, ENRMLinkRegexConfig *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [[NSCache alloc] init];
    cache.countLimit = 64;
  });
  NSString *key = [NSString stringWithFormat:@"%d%d%@", caseInsensitive, dotAll, pattern];
  ENRMLinkRegexConfig *config = [cache objectForKey:key];
  if (!config) {
    config = [[ENRMLinkRegexConfig alloc] initWithPattern:pattern
                                          caseInsensitive:caseInsensitive
                                                   dotAll:dotAll
                                               isDisabled:NO
                                                isDefault:NO];
    [cache setObject:config forKey:key];
  }
  return config;
}

static MarkdownASTNode *ENRMRecognizedLink(MarkdownASTNode *child, NSString *url)
{
  MarkdownASTNode *link = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeLink];
  [link setAttribute:@"url" value:url];
  [link setAttribute:@"recognizedLink" value:@"true"];
  [link addChild:child];
  return link;
}

static MarkdownASTNode *ENRMTextSlice(MarkdownASTNode *node, NSString *content)
{
  MarkdownASTNode *text = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  text.content = content;
  text.attributes = [node.attributes mutableCopy];
  return text;
}

static NSArray<MarkdownASTNode *> *ENRMRecognizeNode(MarkdownASTNode *node, NSRegularExpression *textRegex,
                                                     NSRegularExpression *codeRegex)
{
  switch (node.type) {
    case MarkdownNodeTypeLink:
    case MarkdownNodeTypeCodeBlock:
    case MarkdownNodeTypeImage:
    case MarkdownNodeTypeVideo:
    case MarkdownNodeTypeLatexMathInline:
    case MarkdownNodeTypeLatexMathDisplay:
      return @[ node ];

    case MarkdownNodeTypeCode: {
      NSMutableString *content = [NSMutableString string];
      for (MarkdownASTNode *child in node.children) {
        [content appendString:child.content ?: @""];
      }
      NSRange range = NSMakeRange(0, content.length);
      NSTextCheckingResult *match = [codeRegex firstMatchInString:content options:0 range:range];
      if (content.length > 0 && match && NSEqualRanges(match.range, range)) {
        return @[ ENRMRecognizedLink(node, content) ];
      }
      return @[ node ];
    }

    case MarkdownNodeTypeText: {
      if (!textRegex)
        return @[ node ];
      NSString *content = node.content ?: @"";
      NSMutableArray<MarkdownASTNode *> *result = [NSMutableArray array];
      NSUInteger offset = 0;
      for (NSTextCheckingResult *match in [textRegex matchesInString:content
                                                             options:0
                                                               range:NSMakeRange(0, content.length)]) {
        if (match.range.length == 0)
          continue;
        if (match.range.location > offset) {
          [result addObject:ENRMTextSlice(
                                node, [content substringWithRange:NSMakeRange(offset, match.range.location - offset)])];
        }
        NSString *matched = [content substringWithRange:match.range];
        [result addObject:ENRMRecognizedLink(ENRMTextSlice(node, matched), matched)];
        offset = NSMaxRange(match.range);
      }
      if (offset == 0)
        return @[ node ];
      if (offset < content.length) {
        [result addObject:ENRMTextSlice(node, [content substringFromIndex:offset])];
      }
      return result;
    }

    default: {
      // Rebuild the children array only once a child actually changed.
      NSArray<MarkdownASTNode *> *original = node.children;
      NSMutableArray<MarkdownASTNode *> *children = nil;
      for (NSUInteger index = 0; index < original.count; index++) {
        MarkdownASTNode *child = original[index];
        NSArray<MarkdownASTNode *> *transformed = ENRMRecognizeNode(child, textRegex, codeRegex);
        BOOL unchanged = transformed.count == 1 && transformed[0] == child;
        if (!children) {
          if (unchanged)
            continue;
          children = [[original subarrayWithRange:NSMakeRange(0, index)] mutableCopy];
        }
        [children addObjectsFromArray:transformed];
      }
      if (children)
        node.children = children;
      return @[ node ];
    }
  }
}

void ENRMRecognizeTextLinks(MarkdownASTNode *ast, ENRMLinkRegexConfig *linkRegex,
                            ENRMLinkRegexConfig *inlineCodeLinkRegex)
{
  NSRegularExpression *textRegex = (!linkRegex.isDefault && !linkRegex.isDisabled) ? linkRegex.parsedRegex : nil;
  NSRegularExpression *codeRegex = (!inlineCodeLinkRegex.isDefault && !inlineCodeLinkRegex.isDisabled)
                                       ? inlineCodeLinkRegex.parsedWholeSpanRegex
                                       : nil;
  if (ast && (textRegex || codeRegex)) {
    ENRMRecognizeNode(ast, textRegex, codeRegex);
  }
}

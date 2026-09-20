// Add this source to an iOS XCTest target linked against the library pod.
// It is outside ios/ so XCTest is never imported into the production pod.
#import "ENRMBlockquoteContainerView.h"
#import "ENRMDocumentAssets.h"
#import "ENRMMediaSlotView.h"
#import "MarkdownASTNode.h"
#import "RenderedMarkdownSegment.h"
#import "SegmentRenderer.h"
#import <XCTest/XCTest.h>

static MarkdownASTNode *Node(MarkdownNodeType type, NSArray<MarkdownASTNode *> *children)
{
  MarkdownASTNode *node = [[MarkdownASTNode alloc] initWithType:type];
  [node.children addObjectsFromArray:children];
  return node;
}

static MarkdownASTNode *Image(NSString *url)
{
  MarkdownASTNode *image = Node(MarkdownNodeTypeImage, @[]);
  image.attributes[@"url"] = url;
  return image;
}

static MarkdownASTNode *ImageParagraph(NSString *url)
{
  return Node(MarkdownNodeTypeParagraph, @[ Image(url) ]);
}

static NSDictionary *Override(NSDictionary *asset, CGFloat height, CGFloat width)
{
  return @{
    @"url" : asset[@"url"],
    @"kind" : asset[@"kind"],
    @"anchor" : asset[@"anchor"],
    @"height" : @(height),
    @"width" : @(width)
  };
}

@interface QuoteMediaSlotTests : XCTestCase
@end

@implementation QuoteMediaSlotTests

- (void)testRecursiveQuoteAndAdmonitionAssetsUseGlobalIdentity
{
  MarkdownASTNode *video = Node(MarkdownNodeTypeVideo, @[]);
  video.attributes[@"url"] = @"video://original";
  MarkdownASTNode *admonition = Node(MarkdownNodeTypeAdmonition, @[ video ]);
  MarkdownASTNode *quote = Node(MarkdownNodeTypeBlockquote, @[ ImageParagraph(@"image://original"), admonition ]);
  MarkdownASTNode *root = Node(MarkdownNodeTypeDocument, @[ quote ]);
  NSArray<NSDictionary *> *assets = ENRMPrepareDocumentAssets(root, YES, NO, @{});
  XCTAssertEqual(assets.count, 2u);
  XCTAssertEqualObjects(assets[0][@"id"], @"asset-0");
  XCTAssertEqualObjects(assets[0][@"anchor"], @"0.0.0");
  XCTAssertEqualObjects(assets[1][@"id"], @"asset-1");
  XCTAssertEqualObjects(assets[1][@"anchor"], @"0.0.1.0");
  for (NSDictionary *asset in assets) {
    XCTAssertTrue([asset[@"eligible"] boolValue]);
    XCTAssertEqualObjects(asset[@"placement"], @"blockquote");
  }
  XCTAssertEqualObjects(quote.children[0].attributes[@"_enrmMediaSlot"], @"asset-0");
  XCTAssertEqualObjects(video.attributes[@"_enrmMediaSlot"], @"asset-1");
  // Slot splitting must not depend on whether the optional video module exists.
  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromAST(admonition, [[StyleConfig alloc] init], NO, NO, 0, NSLineBreakStrategyNone, YES);
  XCTAssertEqual(segments.count, 1u);
  XCTAssertEqual(segments[0].kind, ENRMSegmentKindMediaSlot);
}

- (void)testListTableMixedAndLinkedQuoteImagesStayNative
{
  MarkdownASTNode *listQuote = Node(MarkdownNodeTypeBlockquote, @[ ImageParagraph(@"image://list") ]);
  MarkdownASTNode *list = Node(MarkdownNodeTypeUnorderedList, @[ Node(MarkdownNodeTypeListItem, @[ listQuote ]) ]);
  MarkdownASTNode *table =
      Node(MarkdownNodeTypeTable, @[ Node(MarkdownNodeTypeTableCell, @[ ImageParagraph(@"image://table") ]) ]);
  MarkdownASTNode *text = Node(MarkdownNodeTypeText, @[]);
  text.content = @"mixed";
  MarkdownASTNode *mixed = Node(MarkdownNodeTypeParagraph, @[ text, Image(@"image://mixed") ]);
  MarkdownASTNode *link = Node(MarkdownNodeTypeLink, @[ Image(@"image://linked") ]);
  link.attributes[@"url"] = @"link://original";
  MarkdownASTNode *quote =
      Node(MarkdownNodeTypeBlockquote, @[ list, table, mixed, Node(MarkdownNodeTypeParagraph, @[ link ]) ]);
  NSArray<NSDictionary *> *assets = ENRMPrepareDocumentAssets(Node(MarkdownNodeTypeDocument, @[ quote ]), YES, NO, @{});
  XCTAssertEqual(assets.count, 5u);
  for (NSDictionary *asset in assets)
    XCTAssertFalse([asset[@"eligible"] boolValue]);
  XCTAssertNil(listQuote.children[0].attributes[@"_enrmMediaSlot"]);
  XCTAssertNil(mixed.attributes[@"_enrmMediaSlot"]);
}

- (void)testExactNullFallbackAndStaleIdentityStayDistinct
{
  MarkdownASTNode *paragraph = ImageParagraph(@"image://same");
  MarkdownASTNode *quote = Node(MarkdownNodeTypeBlockquote, @[ paragraph ]);
  MarkdownASTNode *root = Node(MarkdownNodeTypeDocument, @[ quote ]);
  NSDictionary *asset = ENRMPrepareDocumentAssets(root, NO, NO, @{})[0];
  ENRMPrepareDocumentAssets(root, YES, YES, @{});
  XCTAssertNil(paragraph.attributes[@"_enrmMediaSlot"]);
  NSMutableDictionary *wrong = [Override(asset, 41, 200) mutableCopy];
  wrong[@"anchor"] = @"0.9.0";
  ENRMPrepareDocumentAssets(root, YES, YES, @{asset[@"id"] : wrong});
  XCTAssertEqualObjects(paragraph.attributes[@"_enrmMediaSlot"], asset[@"id"]);
  XCTAssertNil(paragraph.attributes[@"_enrmMediaHeight"]);
}

- (void)testNestedLiveAndShadowHeightsMatchAndFramesIncludeInsets
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setBlockquotePadding:10];
  [config setBlockquoteBorderWidth:2];
  [config setBlockquoteGapWidth:3];
  [config setImageMarginTop:3];
  [config setImageMarginBottom:7];
  [config setImageHeight:63];
  [config setImageMaxHeight:0];
  [config setImageAspectRatio:0];
  MarkdownASTNode *paragraph = ImageParagraph(@"image://same");
  MarkdownASTNode *inner = Node(MarkdownNodeTypeBlockquote, @[ paragraph ]);
  MarkdownASTNode *outer = Node(MarkdownNodeTypeBlockquote, @[ inner ]);
  MarkdownASTNode *root = Node(MarkdownNodeTypeDocument, @[ outer ]);
  NSDictionary *asset = ENRMPrepareDocumentAssets(root, NO, NO, @{})[0];
  // A prior revision may carry this height only after native identity validation.
  ENRMPrepareDocumentAssets(root, YES, NO, @{asset[@"id"] : Override(asset, 41, 250)});
  ENRMBlockquoteContainerView *view = [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
  [view applyBlockquoteNode:outer];
  CGFloat live = [view measureHeight:300];
  CGFloat shadow = [ENRMBlockquoteContainerView measureHeightForBlockquoteNode:outer
                                                                        config:config
                                                                      maxWidth:300
                                                              pointScaleFactor:1
                                                              allowFontScaling:NO
                                                             lineBreakStrategy:NSLineBreakStrategyNone];
  XCTAssertEqualWithAccuracy(live, 84, 0.01);
  XCTAssertEqualWithAccuracy(live, shadow, 0.01);
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  view.frame = CGRectMake(20, 30, 300, live);
  [host addSubview:view];
  NSMutableArray<NSDictionary *> *frames = [NSMutableArray array];
  [view appendMediaFrames:frames relativeToView:host];
  XCTAssertEqual(frames.count, 1u);
  NSDictionary *frame = frames[0];
  XCTAssertEqualObjects(frame[@"id"], asset[@"id"]);
  XCTAssertEqualWithAccuracy([frame[@"x"] doubleValue], 50, 0.01);
  XCTAssertEqualWithAccuracy([frame[@"y"] doubleValue], 53, 0.01);
  XCTAssertEqualWithAccuracy([frame[@"width"] doubleValue], 250, 0.01);
  XCTAssertEqualWithAccuracy([frame[@"height"] doubleValue], 41, 0.01);
  // Narrowing below the inset width must not publish previous child bounds.
  view.frame = CGRectMake(20, 30, 20, live);
  NSMutableArray<NSDictionary *> *narrowFrames = [NSMutableArray array];
  [view appendMediaFrames:narrowFrames relativeToView:host];
  XCTAssertEqual(narrowFrames.count, 0u);
  // At a new inner width the old React height is rejected by both pipelines.
  XCTAssertEqualWithAccuracy([view measureHeight:350], 106, 0.01);
  XCTAssertEqualWithAccuracy([view measureHeight:350],
                             [ENRMBlockquoteContainerView measureHeightForBlockquoteNode:outer
                                                                                  config:config
                                                                                maxWidth:350
                                                                        pointScaleFactor:1
                                                                        allowFontScaling:NO
                                                                       lineBreakStrategy:NSLineBreakStrategyNone],
                             0.01);
}

- (void)testAdmonitionHeaderRemainsAboveSlot
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setBlockquotePadding:10];
  [config setImageMarginTop:3];
  MarkdownASTNode *paragraph = ImageParagraph(@"image://header");
  MarkdownASTNode *admonition = Node(MarkdownNodeTypeAdmonition, @[ paragraph ]);
  admonition.attributes[@"admonitionType"] = @"note";
  MarkdownASTNode *root = Node(MarkdownNodeTypeDocument, @[ admonition ]);
  NSDictionary *asset = ENRMPrepareDocumentAssets(root, NO, NO, @{})[0];
  ENRMPrepareDocumentAssets(root, YES, YES, @{asset[@"id"] : Override(asset, 41, 0)});
  ENRMBlockquoteContainerView *view = [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
  [view applyBlockquoteNode:admonition];
  view.frame = CGRectMake(0, 0, 300, [view measureHeight:300]);
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  [host addSubview:view];
  NSMutableArray<NSDictionary *> *frames = [NSMutableArray array];
  [view appendMediaFrames:frames relativeToView:host];
  XCTAssertGreaterThan(view.contentInsets.top, 10);
  XCTAssertEqualWithAccuracy([frames[0][@"y"] doubleValue], view.contentInsets.top + 3, 0.01);
  CGFloat shadow = [ENRMBlockquoteContainerView measureHeightForBlockquoteNode:admonition
                                                                        config:config
                                                                      maxWidth:300
                                                              pointScaleFactor:1
                                                              allowFontScaling:NO
                                                             lineBreakStrategy:NSLineBreakStrategyNone];
  XCTAssertEqualWithAccuracy(view.bounds.size.height, shadow, 0.01);
}

@end

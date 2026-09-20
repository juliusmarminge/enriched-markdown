// Add to a host XCTest target linked against the library pod.
// XCTest stays outside ios/ and is not a production dependency.
#import "ENRMDocumentAssets.h"
#import "MarkdownASTNode.h"
#import "RenderedMarkdownSegment.h"
#import "SegmentRenderer.h"
#import <XCTest/XCTest.h>

static MarkdownASTNode *ImageDocument(void)
{
  MarkdownASTNode *root = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  MarkdownASTNode *paragraph = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
  MarkdownASTNode *image = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeImage];
  image.attributes[@"url"] = @"https://example.com/image.png";
  [paragraph.children addObject:image];
  [root.children addObject:paragraph];
  return root;
}

static NSDictionary *Decision(NSDictionary *asset, CGFloat height, CGFloat width)
{
  return @{
    @"url" : asset[@"url"],
    @"kind" : asset[@"kind"],
    @"anchor" : asset[@"anchor"],
    @"height" : @(height),
    @"width" : @(width)
  };
}

@interface RootMediaSlotTests : XCTestCase
@end
@implementation RootMediaSlotTests

- (void)testNullDecisionRetainsNativeImageAndInvalidIdentityRejectsCarriedHeight
{
  MarkdownASTNode *root = ImageDocument();
  NSDictionary *asset = ENRMPrepareDocumentAssets(root, NO, NO, @{})[0];
  ENRMPrepareDocumentAssets(root, YES, YES, @{});
  XCTAssertNil(root.children[0].attributes[@"_enrmMediaSlot"]);
  NSMutableDictionary *wrong = [Decision(asset, 41, 200) mutableCopy];
  wrong[@"anchor"] = @"0.9";
  ENRMPrepareDocumentAssets(root, YES, YES, @{asset[@"id"] : wrong});
  XCTAssertEqualObjects(root.children[0].attributes[@"_enrmMediaSlot"], asset[@"id"]);
  XCTAssertNil(root.children[0].attributes[@"_enrmMediaHeight"]);
}

- (void)testAcceptedImageHeightRequiresMatchingWidth
{
  MarkdownASTNode *root = ImageDocument();
  NSDictionary *asset = ENRMPrepareDocumentAssets(root, NO, NO, @{})[0];
  ENRMPrepareDocumentAssets(root, YES, NO, @{asset[@"id"] : Decision(asset, 41, 200)});
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setImageAspectRatio:0];
  [config setImageMaxHeight:0];
  [config setImageHeight:63];
  XCTAssertEqualWithAccuracy(ENRMMediaSlotHeight(root.children[0], 200, config), 41, 0.01);
  XCTAssertEqualWithAccuracy(ENRMMediaSlotHeight(root.children[0], 250, config), 63, 0.01);
}

- (void)testVideoReplacementSplitsWithoutOptionalNativePlayer
{
  MarkdownASTNode *root = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  MarkdownASTNode *video = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeVideo];
  video.attributes[@"url"] = @"https://example.com/movie.mp4";
  [root.children addObject:video];
  ENRMPrepareDocumentAssets(root, YES, NO, @{});
  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromAST(root, [[StyleConfig alloc] init], NO, NO, 0, NSLineBreakStrategyNone, NO);
  XCTAssertEqual(segments.count, 1u);
  XCTAssertEqual(segments[0].kind, ENRMSegmentKindMediaSlot);
}
@end

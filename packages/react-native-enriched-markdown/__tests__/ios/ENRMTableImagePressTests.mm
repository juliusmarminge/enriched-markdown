#import "../../ios/segments/ENRMTableIOSGridView.h"
#import <XCTest/XCTest.h>

@interface ENRMTableIOSGridView (ImagePressTests)
- (ENRMTableIOSItemHit *)itemAtPoint:(CGPoint)point urlAttribute:(NSString *)attribute;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
@end
@interface ENRMTableTestTap : UITapGestureRecognizer
@property (nonatomic) CGPoint testPoint;
@end
@implementation ENRMTableTestTap
- (CGPoint)locationInView:(UIView *)view
{
  return self.testPoint;
}
- (UIGestureRecognizerState)state
{
  return UIGestureRecognizerStateEnded;
}
@end

@interface ENRMTableImagePressTests : XCTestCase
@end
@implementation ENRMTableImagePressTests
- (ENRMTableIOSGridView *)gridWithLink:(BOOL)linked
{
  NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
  attachment.bounds = CGRectMake(0, 0, 48, 48);
  NSMutableAttributedString *text = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
  [text addAttributes:@{@"imageURL" : @"https://example.com/image.png", @"imageAltText" : @"Table image"}
                range:NSMakeRange(0, 1)];
  if (linked)
    [text addAttribute:@"linkURL" value:@"https://example.com/destination" range:NSMakeRange(0, 1)];
  ENRMTableIOSRowData *row = [[ENRMTableIOSRowData alloc] init];
  row.cellTexts = @[ text ];
  row.backgroundColor = UIColor.whiteColor;
  ENRMTableIOSGridView *grid = [[ENRMTableIOSGridView alloc] initWithFrame:CGRectMake(0, 0, 160, 100)];
  [grid updateWithRows:@[ row ]
               columnWidths:@[ @160 ]
                 rowHeights:@[ @100 ]
                borderColor:UIColor.blackColor
                borderWidth:1
      horizontalCellPadding:12
        verticalCellPadding:12
               cornerRadius:0];
  return grid;
}
- (void)testImageHitPreservesOriginalURLAndAltText
{
  ENRMTableIOSItemHit *hit = [[self gridWithLink:NO] itemAtPoint:CGPointMake(30, 30) urlAttribute:@"imageURL"];
  XCTAssertEqualObjects(hit.url, @"https://example.com/image.png");
  XCTAssertEqualObjects(hit.title, @"Table image");
}
- (void)testCellPaddingDoesNotHitNearestImage
{
  ENRMTableIOSGridView *grid = [self gridWithLink:NO];
  XCTAssertNil([grid itemAtPoint:CGPointMake(8, 30) urlAttribute:@"imageURL"]);
  XCTAssertNil([grid itemAtPoint:CGPointMake(130, 30) urlAttribute:@"imageURL"]);
  XCTAssertNil([grid itemAtPoint:CGPointMake(30, 85) urlAttribute:@"imageURL"]);
}
- (void)testImageTapCallsImageCallback
{
  ENRMTableIOSGridView *grid = [self gridWithLink:NO];
  __block NSString *url, *alt;
  grid.onImageTap = ^(NSString *value, NSString *label) {
    url = value;
    alt = label;
  };
  ENRMTableTestTap *tap = [[ENRMTableTestTap alloc] init];
  tap.testPoint = CGPointMake(30, 30);
  [grid handleTap:tap];
  XCTAssertEqualObjects(url, @"https://example.com/image.png");
  XCTAssertEqualObjects(alt, @"Table image");
}
- (void)testLinkedImageKeepsLinkPriority
{
  ENRMTableIOSGridView *grid = [self gridWithLink:YES];
  __block NSString *url;
  __block BOOL imagePressed = NO;
  grid.onLinkTap = ^(NSString *value) { url = value; };
  grid.onImageTap = ^(NSString *value, NSString *label) { imagePressed = YES; };
  ENRMTableTestTap *tap = [[ENRMTableTestTap alloc] init];
  tap.testPoint = CGPointMake(30, 30);
  [grid handleTap:tap];
  XCTAssertEqualObjects(url, @"https://example.com/destination");
  XCTAssertFalse(imagePressed);
}
@end

#import "../../ios/segments/ENRMTableIOSGridView.h"
#import <XCTest/XCTest.h>

static NSString *const kImageURL = @"https://example.com/image.png";
static NSString *const kLinkURL = @"https://example.com/destination";

@interface ENRMTableImagePressTests : XCTestCase
@end

@implementation ENRMTableImagePressTests

- (ENRMTableIOSGridView *)gridWithCellText:(NSAttributedString *)text
{
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

- (ENRMTableIOSGridView *)gridWithImageLinked:(BOOL)linked
{
  NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
  attachment.bounds = CGRectMake(0, 0, 48, 48);
  NSMutableAttributedString *text = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
  [text addAttributes:@{@"imageURL" : kImageURL, @"imageAltText" : @"Table image"} range:NSMakeRange(0, 1)];
  if (linked)
    [text addAttribute:@"linkURL" value:kLinkURL range:NSMakeRange(0, 1)];
  return [self gridWithCellText:text];
}

- (void)testImageHitPreservesOriginalURLAndAltText
{
  ENRMTableIOSItemHit *hit = [[self gridWithImageLinked:NO] imageAtPoint:CGPointMake(30, 30)];
  XCTAssertEqual(hit.kind, ENRMTableIOSItemKindImage);
  XCTAssertEqualObjects(hit.url, kImageURL);
  XCTAssertEqualObjects(hit.title, @"Table image");
}

- (void)testImageIsNotALink
{
  XCTAssertNil([[self gridWithImageLinked:NO] linkAtPoint:CGPointMake(30, 30)]);
}

- (void)testCellPaddingDoesNotHitNearestImage
{
  ENRMTableIOSGridView *grid = [self gridWithImageLinked:NO];
  XCTAssertNil([grid imageAtPoint:CGPointMake(8, 30)]);
  XCTAssertNil([grid imageAtPoint:CGPointMake(130, 30)]);
  XCTAssertNil([grid imageAtPoint:CGPointMake(30, 85)]);
}

- (void)testLinkedImageIsALink
{
  ENRMTableIOSGridView *grid = [self gridWithImageLinked:YES];
  ENRMTableIOSItemHit *hit = [grid linkAtPoint:CGPointMake(30, 30)];
  XCTAssertEqual(hit.kind, ENRMTableIOSItemKindLink);
  XCTAssertEqualObjects(hit.url, kLinkURL);
  XCTAssertNil([grid imageAtPoint:CGPointMake(30, 30)]);
}

- (void)testLinkStillResolvesToNearestGlyph
{
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Go"];
  [text addAttribute:@"linkURL" value:kLinkURL range:NSMakeRange(0, 2)];
  ENRMTableIOSGridView *grid = [self gridWithCellText:text];
  XCTAssertEqualObjects([grid linkAtPoint:CGPointMake(100, 20)].url, kLinkURL);
}

@end

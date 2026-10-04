#import "AttributedRenderer.h"
#import "ENRMImageDownloader.h"
#import "ENRMLinkPillAttachment.h"
#import "ENRMLinkPillIconCache.h"
#import "ENRMLinkPillText.h"
#import "ENRMMarkdownParser.h"
#import "ENRMMarkdownTextView.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMTextRenderer.h"
#import "HTMLGenerator.h"
#import "LastElementUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownExtractor.h"
#import "RenderContext.h"
#import "StyleConfig.h"
#import <XCTest/XCTest.h>

static NSString *const kDocURL = @"https://example.com/doc";

@interface ENRMLinkPillAttachmentTests : XCTestCase
@end

@implementation ENRMLinkPillAttachmentTests

- (LinkVariantConfig *)variantWithPill:(BOOL)pill
{
  LinkVariantConfig *variant = [LinkVariantConfig new];
  variant.pattern = @"^https://example\\.com/";
  variant.fontFamily = @"";
  variant.color = UIColor.redColor;
  variant.backgroundColor = UIColor.greenColor;
  if (pill) {
    LinkPillConfig *config = [LinkPillConfig new];
    config.label = @"";
    config.iconUri = @"";
    config.borderColor = UIColor.clearColor;
    config.borderRadius = 8;
    config.paddingHorizontal = 6;
    config.paddingVertical = 2;
    variant.pill = config;
  }
  return variant;
}

- (StyleConfig *)configWithPill:(BOOL)pill
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setParagraphFontSize:16];
  [config setParagraphColor:UIColor.blackColor];
  [config setLinkColor:UIColor.blueColor];
  [config setLinkVariants:@[ [self variantWithPill:pill] ]];
  return config;
}

- (NSMutableAttributedString *)render:(NSString *)markdown config:(StyleConfig *)config
{
  MarkdownASTNode *ast = [[ENRMMarkdownParser new] parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags] isGFM:NO];
  XCTAssertNotNil(ast);
  return ENRMRenderASTNodes(ast.children, config, NO, NO, 0, NSLineBreakStrategyNone).attributedText;
}

- (NSArray<ENRMLinkPillAttachment *> *)pillsIn:(NSAttributedString *)text
{
  NSMutableArray *pills = [NSMutableArray new];
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:ENRMLinkPillAttachment.class])
                    [pills addObject:value];
                }];
  return pills;
}

- (LinkPillContent *)contentWithLabel:(NSString *)label iconUri:(NSString *)iconUri
{
  LinkPillContent *content = [LinkPillContent new];
  content.label = label;
  content.iconUri = iconUri;
  return content;
}

#pragma mark - Storage shape

- (void)testPillLinkIsOneAttachmentCharacterCarryingTheLink
{
  NSAttributedString *text = [self render:@"see [original label](https://example.com/doc) end"
                                   config:[self configWithPill:YES]];
  XCTAssertEqualObjects(text.string, @"see ￼ end");
  ENRMLinkPillAttachment *pill = [self pillsIn:text].firstObject;
  XCTAssertNotNil(pill);
  XCTAssertEqualObjects(pill.originalText.string, @"original label");
  XCTAssertEqualObjects([text attribute:@"linkURL" atIndex:4 effectiveRange:NULL], kDocURL);
  // Decoration of the replaced text must not leak around the pill.
  XCTAssertNil([text attribute:NSBackgroundColorAttributeName atIndex:4 effectiveRange:NULL]);
  XCTAssertNil([text attribute:NSUnderlineStyleAttributeName atIndex:4 effectiveRange:NULL]);
}

- (void)testVariantsWithoutPillAndLinksWithLineBreaksStayOrdinaryLinks
{
  NSAttributedString *ordinary = [self render:@"[label](https://example.com/doc)" config:[self configWithPill:NO]];
  XCTAssertEqual([self pillsIn:ordinary].count, 0u);
  XCTAssertEqualObjects(ordinary.string, @"label");

  NSAttributedString *broken = [self render:@"[line one  \nline two](https://example.com/doc)"
                                     config:[self configWithPill:YES]];
  XCTAssertEqual([self pillsIn:broken].count, 0u);
  XCTAssertTrue([broken.string containsString:@"line two"]);
}

- (void)testTextEndingWithPillIsNotTreatedAsTrailingImage
{
  NSAttributedString *text = [self render:@"ends with [label](https://example.com/doc)"
                                   config:[self configWithPill:YES]];
  XCTAssertEqual([self pillsIn:text].count, 1u);
  XCTAssertFalse(isLastElementImage(text));
}

#pragma mark - Text leaving the view

- (void)testMarkdownExportMatchesOrdinaryLinks
{
  NSArray<NSString *> *documents = @[
    @"see [original label](https://example.com/doc) end",
    @"**bold [label](https://example.com/doc) text**",
    @"*italic [label](https://example.com/doc)*",
    @"[`src/file.ts`](https://example.com/doc) and [**strong**](https://example.com/doc)",
    @"[one](https://example.com/a)[two](https://example.com/b)",
    @"# Heading [label](https://example.com/doc)",
    @"- item [label](https://example.com/doc)\n- second",
    @"> quote [label](https://example.com/doc)",
    @"[label](https://example.com/doc)",
  ];
  for (NSString *markdown in documents) {
    NSAttributedString *ordinary = [self render:markdown config:[self configWithPill:NO]];
    NSAttributedString *pilled = [self render:markdown config:[self configWithPill:YES]];
    XCTAssertGreaterThan([self pillsIn:pilled].count, 0u, @"%@", markdown);
    XCTAssertEqualObjects(extractMarkdownFromAttributedString(pilled, NSMakeRange(0, pilled.length)),
                          extractMarkdownFromAttributedString(ordinary, NSMakeRange(0, ordinary.length)), @"%@",
                          markdown);
    XCTAssertEqualObjects(ENRMAttributedStringByExpandingLinkPills(pilled, NULL).string, ordinary.string, @"%@",
                          markdown);
  }
}

- (void)testHTMLExportsCarryTheLinkIncludingTableCells
{
  StyleConfig *config = [self configWithPill:YES];
  NSAttributedString *pilled = [self render:@"see [original label](https://example.com/doc) end" config:config];
  NSString *html = generateHTML(pilled, config);
  XCTAssertTrue([html containsString:@"original label"], @"%@", html);
  XCTAssertTrue([html containsString:@"https://example.com/doc"], @"%@", html);
  XCTAssertFalse([html containsString:@"\uFFFC"]);

  // The table copies cells as they are drawn, placeholders included.
  NSString *table =
      generateTableHTML(@[ @[ @{@"attributedText" : pilled, @"isHeader" : @NO, @"alignment" : @0} ] ], config);
  XCTAssertTrue([table containsString:@"original label"], @"%@", table);
  XCTAssertTrue([table containsString:@"https://example.com/doc"], @"%@", table);
}

- (void)testExpansionRemapsSelectionRanges
{
  // "ab ￼ cd ￼ ef" with originals "first" and "second".
  NSAttributedString *text = [self render:@"ab [first](https://example.com/a) cd [second](https://example.com/b) ef"
                                   config:[self configWithPill:YES]];
  XCTAssertEqualObjects(text.string, @"ab ￼ cd ￼ ef");
  NSString *expandedAll = @"ab first cd second ef";

  NSRange whole = NSMakeRange(0, text.length);
  XCTAssertEqualObjects(ENRMAttributedStringByExpandingLinkPills(text, &whole).string, expandedAll);
  XCTAssertTrue(NSEqualRanges(whole, NSMakeRange(0, expandedAll.length)));

  // Selection after the first pill and containing the second.
  NSRange tail = NSMakeRange(5, 5); // "cd ￼ "
  NSAttributedString *expanded = ENRMAttributedStringByExpandingLinkPills(text, &tail);
  XCTAssertEqualObjects([expanded.string substringWithRange:tail], @"cd second ");

  NSRange head = NSMakeRange(0, 2);
  expanded = ENRMAttributedStringByExpandingLinkPills(text, &head);
  XCTAssertEqualObjects([expanded.string substringWithRange:head], @"ab");

  NSAttributedString *plain = [self render:@"no pills here" config:[self configWithPill:YES]];
  XCTAssertEqual(ENRMAttributedStringByExpandingLinkPills(plain, NULL), plain);
}

- (void)testSystemSelectionRequestsReceiveLinkText
{
  // Look Up, Translate and Share read the selection through UITextInput.
  ENRMMarkdownTextView *view = [[ENRMMarkdownTextView alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
  view.editable = NO;
  view.attributedText = [self render:@"see [original label](https://example.com/doc) end"
                              config:[self configWithPill:YES]];
  XCTAssertEqualObjects(view.textStorage.string, @"see \uFFFC end");

  view.selectedRange = NSMakeRange(0, view.textStorage.length);
  XCTAssertEqualObjects([view textInRange:view.selectedTextRange], @"see original label end");
  XCTAssertEqualObjects([view attributedTextInRange:view.selectedTextRange].string, @"see original label end");

  // Other ranges (word-boundary lookups) keep matching storage offsets.
  UITextRange *prefix = [view textRangeFromPosition:view.beginningOfDocument
                                         toPosition:[view positionFromPosition:view.beginningOfDocument offset:5]];
  XCTAssertEqualObjects([view textInRange:prefix], @"see \uFFFC");

  view.selectedRange = NSMakeRange(0, 3);
  XCTAssertEqualObjects([view textInRange:view.selectedTextRange], @"see");

  view.selectedRange = NSMakeRange(0, view.textStorage.length);
  [view copy:nil];
  XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"see original label end");

  // With a host attached, the key command is handed over so it can write every flavor.
  __block NSRange handedOver = NSMakeRange(NSNotFound, 0);
  view.copySelectionHandler = ^(NSRange range) { handedOver = range; };
  [view copy:nil];
  XCTAssertTrue(NSEqualRanges(handedOver, NSMakeRange(0, view.textStorage.length)));
}

#pragma mark - Content and accessibility

- (void)testPerLinkContentWinsOverVariantLabelWhichWinsOverLinkText
{
  StyleConfig *config = [self configWithPill:YES];
  NSString *markdown = @"[original](https://example.com/doc) [other](https://example.com/other)";
  NSArray<ENRMLinkPillAttachment *> *pills = [self pillsIn:[self render:markdown config:config]];
  XCTAssertEqualObjects(pills[0].linkAccessibilityLabel, @"original");

  config.linkVariants.firstObject.pill.label = @"Variant";
  pills = [self pillsIn:[self render:markdown config:config]];
  XCTAssertEqualObjects(pills[0].linkAccessibilityLabel, @"Variant, original");
  XCTAssertEqualObjects(pills[1].linkAccessibilityLabel, @"Variant, other");

  [config setLinkPillContent:@{kDocURL : [self contentWithLabel:@"Per link" iconUri:@""]}];
  pills = [self pillsIn:[self render:markdown config:config]];
  XCTAssertEqualObjects(pills[0].linkAccessibilityLabel, @"Per link, original");
  XCTAssertEqualObjects(pills[1].linkAccessibilityLabel, @"Variant, other");
}

#pragma mark - Layout and drawing

- (CGRect)boundsOf:(ENRMLinkPillAttachment *)pill inWidth:(CGFloat)width
{
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(width, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  return [pill attachmentBoundsForTextContainer:container
                           proposedLineFragment:CGRectMake(0, 0, width, 30)
                                  glyphPosition:CGPointZero
                                 characterIndex:0];
}

- (void)testPillWidthFollowsLabelAndRespectsContainerAndMaxWidth
{
  StyleConfig *config = [self configWithPill:YES];
  NSString *markdown = @"[a fairly long original link label here](https://example.com/doc)";
  ENRMLinkPillAttachment *pill = [self pillsIn:[self render:markdown config:config]].firstObject;
  CGFloat natural = [self boundsOf:pill inWidth:1000].size.width;
  XCTAssertGreaterThan(natural, 200);
  XCTAssertEqualWithAccuracy([self boundsOf:pill inWidth:120].size.width, 120, 0.01);

  config.linkVariants.firstObject.pill.maxWidth = 90;
  pill = [self pillsIn:[self render:markdown config:config]].firstObject;
  XCTAssertEqualWithAccuracy([self boundsOf:pill inWidth:1000].size.width, 90, 0.01);

  // String drawing (table cells) has no text container; the proposed fragment bounds the pill.
  CGRect free = [pill attachmentBoundsForTextContainer:nil
                                  proposedLineFragment:CGRectMake(0, 0, 60, 30)
                                         glyphPosition:CGPointZero
                                        characterIndex:0];
  XCTAssertEqualWithAccuracy(free.size.width, 60, 0.01);
}

- (void)testStringDrawingMeasuresAndPaintsThePill
{
  NSAttributedString *text = [self render:@"cell [label](https://example.com/doc)" config:[self configWithPill:YES]];
  ENRMLinkPillAttachment *pill = [self pillsIn:text].firstObject;
  CGRect bounds = [text boundingRectWithSize:CGSizeMake(300, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     context:nil];
  XCTAssertGreaterThanOrEqual(bounds.size.height, pill.boxHeight - 0.01);
  XCTAssertGreaterThan(bounds.size.width, [self boundsOf:pill inWidth:300].size.width);

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 1;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(300, 60) format:format];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [text drawWithRect:CGRectMake(0, 0, 300, 60)
               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
               context:nil];
  }];
  size_t width = CGImageGetWidth(image.CGImage), height = CGImageGetHeight(image.CGImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                              kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(space);
  CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
  CGContextRelease(bitmap);
  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  NSUInteger green = 0;
  for (size_t offset = 0; offset < pixels.length; offset += 4)
    if (bytes[offset] < 40 && bytes[offset + 1] > 215 && bytes[offset + 2] < 40 && bytes[offset + 3] > 200)
      green++;
  XCTAssertGreaterThan(green, 100u, @"the pill background must be painted by plain string drawing");
}

- (void)testLabelAdoptsWeightOfEnclosingBoldText
{
  StyleConfig *config = [self configWithPill:YES];
  ENRMLinkPillAttachment *regular =
      [self pillsIn:[self render:@"text [a label to measure](https://example.com/doc)" config:config]].firstObject;
  ENRMLinkPillAttachment *bold =
      [self pillsIn:[self render:@"**text [a label to measure](https://example.com/doc)**" config:config]].firstObject;
  XCTAssertGreaterThan([self boundsOf:bold inWidth:1000].size.width, [self boundsOf:regular inWidth:1000].size.width);
}

- (void)testTableCellRenderingAdoptsWeightOfEnclosingBoldText
{
  // Table cells render through AttributedRenderer directly, not ENRMRenderASTNodes.
  StyleConfig *config = [self configWithPill:YES];
  CGFloat (^cellPillWidth)(NSString *) = ^CGFloat(NSString *markdown) {
    MarkdownASTNode *ast = [[ENRMMarkdownParser new] parseMarkdown:markdown
                                                             flags:[ENRMMd4cFlags defaultFlags]
                                                             isGFM:NO];
    NSAttributedString *text = [[[AttributedRenderer alloc] initWithConfig:config] renderNodes:ast.children
                                                                                       context:[RenderContext new]
                                                                                         block:nil];
    return [self boundsOf:[self pillsIn:text].firstObject inWidth:1000].size.width;
  };
  XCTAssertGreaterThan(cellPillWidth(@"**[a label to measure](https://example.com/doc)**"),
                       cellPillWidth(@"[a label to measure](https://example.com/doc)"));
}

- (void)testExpansionKeepsTheWeightOfEachRunOfTheLink
{
  StyleConfig *config = [self configWithPill:YES];
  BOOL (^isBold)(NSAttributedString *, NSString *) = ^BOOL(NSAttributedString *text, NSString *word) {
    UIFont *font = [text attribute:NSFontAttributeName
                           atIndex:[text.string rangeOfString:word].location
                    effectiveRange:NULL];
    return (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
  };
  NSAttributedString *mixed = ENRMAttributedStringByExpandingLinkPills(
      [self render:@"[**Note** details](https://example.com/doc)" config:config], NULL);
  XCTAssertEqualObjects(mixed.string, @"Note details");
  XCTAssertTrue(isBold(mixed, @"Note"));
  XCTAssertFalse(isBold(mixed, @"details"), @"bold of the link's first run must not spread to the rest");

  // Bold applied around the link, after the pill was made, does reach all of it.
  NSAttributedString *enclosed = ENRMAttributedStringByExpandingLinkPills(
      [self render:@"**[Note details](https://example.com/doc)**" config:config], NULL);
  XCTAssertTrue(isBold(enclosed, @"details"));
}

#pragma mark - Spoilers

- (NSUInteger)paintedPixelsIn:(UIImage *)image
{
  if (!image.CGImage)
    return 0;
  size_t width = CGImageGetWidth(image.CGImage), height = CGImageGetHeight(image.CGImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                              kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(space);
  CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
  CGContextRelease(bitmap);
  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  NSUInteger painted = 0;
  for (size_t offset = 3; offset < pixels.length; offset += 4)
    if (bytes[offset] > 0)
      painted++;
  return painted;
}

- (void)testLinkHoldingASpoilerStaysAnOrdinaryLink
{
  NSAttributedString *text = [self render:@"[see ||secret||](https://example.com/doc)"
                                   config:[self configWithPill:YES]];
  XCTAssertEqualObjects(text.string, @"see secret");
  XCTAssertEqual([self pillsIn:text].count, 0u, @"the label would show the hidden text");
}

- (void)testPillInsideASpoilerIsNotDrawnUntilRevealed
{
  ENRMMarkdownTextView *view = [[ENRMMarkdownTextView alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
  view.attributedText = [self render:@"||[secret](https://example.com/doc)||" config:[self configWithPill:YES]];
  ENRMLinkPillAttachment *pill = [self pillsIn:view.textStorage].firstObject;
  XCTAssertNotNil(pill);
  CGRect bounds = CGRectMake(0, 0, 80, 24);
  UIImage *concealed = [pill imageForBounds:bounds textContainer:view.textContainer characterIndex:0];
  XCTAssertEqual([self paintedPixelsIn:concealed], 0u);

  [view.textStorage removeAttribute:SpoilerAttributeName range:NSMakeRange(0, view.textStorage.length)];
  UIImage *revealed = [pill imageForBounds:bounds textContainer:view.textContainer characterIndex:0];
  XCTAssertGreaterThan([self paintedPixelsIn:revealed], 100u);
}

#pragma mark - Icons

- (NSString *)dataUriForPNGOfSize:(CGFloat)side
{
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 1;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)
                                                                             format:format];
  NSData *png = UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [UIColor.redColor setFill];
    UIRectFill(CGRectMake(0, 0, side, side));
  }]);
  return [@"data:image/png;base64," stringByAppendingString:[png base64EncodedStringWithOptions:0]];
}

- (void)testNonFileIconLoadsThroughTheImagePipelineAndKeepsItsSlot
{
  StyleConfig *config = [self configWithPill:YES];
  NSString *markdown = @"[label](https://example.com/doc)";
  CGFloat withoutIcon =
      [self boundsOf:[self pillsIn:[self render:markdown config:config]].firstObject inWidth:1000].size.width;

  NSString *iconUri = [self dataUriForPNGOfSize:400];
  [config setLinkPillContent:@{kDocURL : [self contentWithLabel:@"" iconUri:iconUri]}];
  ENRMLinkPillAttachment *pill = [self pillsIn:[self render:markdown config:config]].firstObject;
  // The slot is reserved before the icon arrives, so loading only needs a redraw.
  CGFloat reserved = [self boundsOf:pill inWidth:1000].size.width;
  XCTAssertEqualWithAccuracy(reserved, withoutIcon + 16 * 1.25, 1.0);

  XCTestExpectation *loaded = [self expectationWithDescription:@"icon loaded"];
  pill.onIconLoaded = ^{ [loaded fulfill]; };
  [self waitForExpectations:@[ loaded ] timeout:10];
  UIImage *icon = ENRMCachedLinkPillIcon(iconUri, nil);
  XCTAssertNotNil(icon);
  XCTAssertLessThanOrEqual(MAX(icon.size.width * icon.scale, icon.size.height * icon.scale), 128);
  XCTAssertEqualWithAccuracy([self boundsOf:pill inWidth:1000].size.width, reserved, 0.01);

  // A later render finds the icon synchronously.
  ENRMLinkPillAttachment *again = [self pillsIn:[self render:markdown config:config]].firstObject;
  XCTAssertEqualWithAccuracy([self boundsOf:again inWidth:1000].size.width, reserved, 0.01);
}

- (void)testPillsWaitingForTheSameIconShareOneThumbnail
{
  NSString *iconUri = [self dataUriForPNGOfSize:300];
  XCTestExpectation *loaded = [self expectationWithDescription:@"icons loaded"];
  loaded.expectedFulfillmentCount = 2;
  NSMutableArray<UIImage *> *icons = [NSMutableArray new];
  for (int request = 0; request < 2; request++) {
    ENRMLoadLinkPillIconAsync(iconUri, nil, ^(UIImage *icon) {
      if (icon)
        [icons addObject:icon];
      [loaded fulfill];
    });
  }
  [self waitForExpectations:@[ loaded ] timeout:10];
  XCTAssertEqual(icons.count, 2u);
  // Drawn pills are cached by icon identity, so equal pills must hold the same image.
  XCTAssertTrue(icons.firstObject == icons.lastObject);
}

- (void)testLocalIconFollowsItsFileAfterTheRevalidationInterval
{
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"enrm-pill-icon.png"];
  void (^writeIcon)(CGFloat) = ^(CGFloat side) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)
                                                                               format:format];
    [UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
      [UIColor.redColor setFill];
      UIRectFill(CGRectMake(0, 0, side, side));
    }]) writeToFile:path
         atomically:YES];
  };
  writeIcon(16);
  UIImage *first = ENRMLoadLinkPillIcon(path);
  XCTAssertEqualWithAccuracy(first.size.width, 16, 0.01);

  writeIcon(24);
  XCTAssertEqual(ENRMLoadLinkPillIcon(path), first, @"within the interval the file is not looked at again");
  [NSThread sleepForTimeInterval:1.1];
  XCTAssertEqualWithAccuracy(ENRMLoadLinkPillIcon(path).size.width, 24, 0.01);
  [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

- (void)testFailedIconReleasesItsSlot
{
  StyleConfig *config = [self configWithPill:YES];
  NSString *markdown = @"[label](https://example.com/doc)";
  CGFloat withoutIcon =
      [self boundsOf:[self pillsIn:[self render:markdown config:config]].firstObject inWidth:1000].size.width;
  NSString *iconUri = @"data:image/png;base64,bm90IGFuIGltYWdl";
  [config setLinkPillContent:@{kDocURL : [self contentWithLabel:@"" iconUri:iconUri]}];
  ENRMLinkPillAttachment *pill = [self pillsIn:[self render:markdown config:config]].firstObject;
  XCTestExpectation *settled = [self expectationWithDescription:@"icon settled"];
  pill.onIconLoaded = ^{ [settled fulfill]; };
  [self waitForExpectations:@[ settled ] timeout:10];
  XCTAssertTrue(ENRMLinkPillIconDidFail(iconUri, nil));
  XCTAssertEqualWithAccuracy([self boundsOf:pill inWidth:1000].size.width, withoutIcon, 0.01);
  // Later renders do not reserve a slot for a source known to fail.
  ENRMLinkPillAttachment *again = [self pillsIn:[self render:markdown config:config]].firstObject;
  XCTAssertEqualWithAccuracy([self boundsOf:again inWidth:1000].size.width, withoutIcon, 0.01);
}

@end

#import "../../ios/utils/ENRMHorizontalScrollView.h"
#import <XCTest/XCTest.h>

static const CGPoint kOutwardPan = {100, 0};

@interface ENRMHorizontalScrollViewTests : XCTestCase
@end

@implementation ENRMHorizontalScrollViewTests

- (void)testSettledLeadingEdgeYieldsOutwardPan
{
  XCTAssertTrue(ENRMShouldYieldOutwardPan(0, 0, NO, kOutwardPan));
}

- (void)testPanFromInsideContentIsKept
{
  XCTAssertFalse(ENRMShouldYieldOutwardPan(80, 0, NO, kOutwardPan));
}

- (void)testInwardPanIsKept
{
  XCTAssertFalse(ENRMShouldYieldOutwardPan(0, 0, NO, CGPointMake(-100, 0)));
}

- (void)testVerticalPanIsKept
{
  XCTAssertFalse(ENRMShouldYieldOutwardPan(0, 0, NO, CGPointMake(20, 100)));
}

- (void)testPanDuringDecelerationIsKept
{
  XCTAssertFalse(ENRMShouldYieldOutwardPan(0, 0, YES, kOutwardPan));
}

- (void)testPanDuringUnfinishedBounceIsKept
{
  XCTAssertFalse(ENRMShouldYieldOutwardPan(-12, 0, NO, kOutwardPan));
}

- (void)testLeadingEdgeIncludesContentInset
{
  XCTAssertTrue(ENRMShouldYieldOutwardPan(-16, -16, NO, kOutwardPan));
  XCTAssertFalse(ENRMShouldYieldOutwardPan(0, -16, NO, kOutwardPan));
}

@end

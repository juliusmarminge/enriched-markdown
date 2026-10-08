#import "../../ios/utils/ENRMHorizontalScrollView.h"
#import <XCTest/XCTest.h>

@interface ENRMTestPan : UIPanGestureRecognizer
@property (nonatomic) CGPoint testVelocity;
@end
@implementation ENRMTestPan
- (CGPoint)velocityInView:(UIView *)view
{
  return self.testVelocity;
}
@end

@interface ENRMTestHorizontalScroll : ENRMHorizontalScrollView
@property (nonatomic, strong) ENRMTestPan *testPan;
@property (nonatomic) BOOL testDecelerating;
@end
@implementation ENRMTestHorizontalScroll
- (UIPanGestureRecognizer *)panGestureRecognizer
{
  return self.testPan ?: [super panGestureRecognizer];
}
- (BOOL)isDecelerating
{
  return self.testDecelerating;
}
@end

@interface ENRMHorizontalScrollViewTests : XCTestCase
@end
@implementation ENRMHorizontalScrollViewTests
- (ENRMTestHorizontalScroll *)scroll
{
  ENRMTestHorizontalScroll *scroll = [[ENRMTestHorizontalScroll alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
  scroll.contentSize = CGSizeMake(900, 100);
  scroll.testPan = [[ENRMTestPan alloc] init];
  scroll.testPan.testVelocity = CGPointMake(100, 0);
  return scroll;
}
- (void)testSettledLeftBoundaryYieldsOutwardPan
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  XCTAssertFalse([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
  XCTAssertTrue(scroll.bounces);
}
- (void)testReturnFromInsideContentRetainsPanAndBounce
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.contentOffset = CGPointMake(80, 0);
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
  XCTAssertTrue(scroll.bounces);
}
- (void)testInwardPanStillScrollsFromLeftBoundary
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.testPan.testVelocity = CGPointMake(-100, 0);
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
}
- (void)testVerticalPanUsesNormalScrollBehavior
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.testPan.testVelocity = CGPointMake(20, 100);
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
}
- (void)testDeceleratingAtBoundaryDoesNotHandOff
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.testDecelerating = YES;
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
}
- (void)testUnsettledBounceDoesNotHandOff
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.contentOffset = CGPointMake(-12, 0);
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
}
- (void)testLeftBoundaryIncludesContentInset
{
  ENRMTestHorizontalScroll *scroll = [self scroll];
  scroll.contentInset = UIEdgeInsetsMake(0, 16, 0, 0);
  scroll.contentOffset = CGPointMake(-16, 0);
  XCTAssertFalse([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
  scroll.contentOffset = CGPointMake(0, 0);
  XCTAssertTrue([scroll gestureRecognizerShouldBegin:scroll.panGestureRecognizer]);
}
@end

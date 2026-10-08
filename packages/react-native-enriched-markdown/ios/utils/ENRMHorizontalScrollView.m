#import "ENRMHorizontalScrollView.h"

#if !TARGET_OS_OSX
@implementation ENRMHorizontalScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.bounces = YES;
  }
  return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer) {
    CGPoint velocity = [self.panGestureRecognizer velocityInView:self];
    CGFloat leftBoundary = -self.adjustedContentInset.left;
    // Decide only when the pan begins. A pan returning from inside the content keeps its bounce.
    BOOL atSettledLeftBoundary = !self.isDecelerating && fabs(self.contentOffset.x - leftBoundary) <= 0.5;
    if (velocity.x > fabs(velocity.y) && atSettledLeftBoundary) {
      return NO;
    }
  }
  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end
#endif

#import "ENRMHorizontalScrollView.h"

#if !TARGET_OS_OSX
@implementation ENRMHorizontalScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.bounces = NO;
  }
  return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer) {
    CGPoint velocity = [self.panGestureRecognizer velocityInView:self];
    CGFloat leftBoundary = -self.adjustedContentInset.left;
    if (velocity.x > fabs(velocity.y) && self.contentOffset.x <= leftBoundary + 0.5) {
      return NO;
    }
  }
  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end
#endif

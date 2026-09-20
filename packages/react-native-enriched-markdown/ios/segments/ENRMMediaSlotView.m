#import "ENRMMediaSlotView.h"
@implementation ENRMMediaSlotView
- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
#if !TARGET_OS_OSX
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    self.userInteractionEnabled = NO;
#endif
  }
  return self;
}
@end

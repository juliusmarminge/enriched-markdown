#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <React/RCTUIKit.h>
#define ENRMHorizontalScrollView RCTUIScrollView
#else
#import <UIKit/UIKit.h>

// Horizontal blocks yield an outward pan at their left boundary to navigation.
@interface ENRMHorizontalScrollView : UIScrollView
@end
#endif

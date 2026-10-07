#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
@class LinkVariantConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * A link presented as a pill. Like image and inline-math attachments it is a
 * single U+FFFC in text storage, laid out and drawn by TextKit natively.
 * The link's own rendered text is kept here; ENRMLinkPillText.h puts it back
 * wherever text leaves the view (copy, export, accessibility).
 */
@interface ENRMLinkPillAttachment : NSTextAttachment
@property (nonatomic, readonly) CGFloat boxHeight;
/// The minimum line height the pill asks of the block that holds it (`pill.lineHeight`); 0 for none.
@property (nonatomic, assign) CGFloat lineHeight;
/// Visible label, followed by the original link text when they differ.
@property (nonatomic, readonly) NSString *linkAccessibilityLabel;
@property (nonatomic, readonly) NSAttributedString *originalText;
/// Called on the main thread when an asynchronously loaded icon settles. For hosts that draw the
/// string themselves (the table grid) and have no text view for the attachment to invalidate.
@property (nonatomic, copy, nullable) void (^onIconLoaded)(void);

/// `variant.pill` must be non-nil. `label`, `iconUri` and `iconTintColor` are already resolved (per-link content,
/// then variant default).
- (instancetype)initWithOriginalText:(NSAttributedString *)originalText
                             variant:(LinkVariantConfig *)variant
                               label:(nullable NSString *)label
                             iconUri:(nullable NSString *)iconUri
                       iconTintColor:(nullable UIColor *)iconTintColor
                                font:(nullable UIFont *)font
                      requestHeaders:(nullable NSDictionary<NSString *, NSString *> *)requestHeaders;

- (void)adoptFont:(nullable UIFont *)font;
@end

NS_ASSUME_NONNULL_END
#endif

#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/**
 * The read-only text view markdown renders into. A link pill is one placeholder character
 * in text storage; what the system reads for the selection (Look Up, Translate, Share,
 * drag, the Copy key command) is answered here with the link text the pill stands for.
 */
@interface ENRMMarkdownTextView : UITextView
/// Copies a selection the way the menu Copy does. Set by the hosting view, which knows the
/// source Markdown and style; without it the Copy key command writes plain text and RTF only.
@property (nonatomic, copy, nullable) void (^copySelectionHandler)(NSRange selectedRange);
@end

NS_ASSUME_NONNULL_END
#endif

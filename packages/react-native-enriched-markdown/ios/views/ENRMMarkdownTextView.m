#import "ENRMMarkdownTextView.h"
#import "ENRMLinkPillText.h"
#import "PasteboardUtils.h"

#if !TARGET_OS_OSX
@implementation ENRMMarkdownTextView

/// The selection with pills expanded, or nil when `range` is not the selection or holds no pill.
/// Only the selection is rewritten: UIKit also reads arbitrary ranges to find word boundaries,
/// and those must keep matching storage offsets.
- (nullable NSAttributedString *)expandedSelectionForRange:(UITextRange *)range
{
  UITextRange *selection = self.selectedTextRange;
  if (!range || !selection || selection.isEmpty || ![range isEqual:selection])
    return nil;
  NSRange selected = self.selectedRange;
  NSTextStorage *storage = self.textStorage;
  if (selected.location == NSNotFound || NSMaxRange(selected) > storage.length)
    return nil;
  NSAttributedString *text = [storage attributedSubstringFromRange:selected];
  NSAttributedString *expanded = ENRMAttributedStringByExpandingLinkPills(text, NULL);
  return expanded == text ? nil : expanded;
}

- (NSString *)textInRange:(UITextRange *)range
{
  return [self expandedSelectionForRange:range].string ?: [super textInRange:range];
}

- (NSAttributedString *)attributedTextInRange:(UITextRange *)range
{
  return [self expandedSelectionForRange:range] ?: [super attributedTextInRange:range];
}

/// The menu's Copy is already replaced by the library's own action; this covers the key command.
- (void)copy:(id)sender
{
  NSRange selected = self.selectedRange;
  if (self.copySelectionHandler && selected.location != NSNotFound && selected.length > 0) {
    self.copySelectionHandler(selected);
    return;
  }
  NSAttributedString *expanded = [self expandedSelectionForRange:self.selectedTextRange];
  if (!expanded) {
    [super copy:sender];
    return;
  }
  copyAttributedStringToPasteboard(expanded, nil, nil);
}

@end
#endif

#import "ENRMLinkPillTextStorage.h"
#import "ENRMLinkPillAttachment.h"

#if !TARGET_OS_OSX
@implementation ENRMLinkPillTextStorage {
  NSMutableAttributedString *_backing;
}

- (instancetype)init
{
  self = [super init];
  if (self)
    _backing = [[NSMutableAttributedString alloc] init];
  return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)text
{
  self = [self init];
  if (self)
    [self setAttributedString:text];
  return self;
}

- (NSString *)string
{
  return _backing.string;
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range
{
  return [_backing attributesAtIndex:index effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)text
{
  [_backing replaceCharactersInRange:range withString:text];
  [self edited:NSTextStorageEditedCharacters
               range:range
      changeInLength:(NSInteger)text.length - (NSInteger)range.length];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes range:(NSRange)range
{
  [_backing setAttributes:attributes range:range];
  [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

- (void)fixAttributesInRange:(NSRange)range
{
  // Foundation removes NSAttachmentAttributeName unless the source character is U+FFFC.
  // A pill deliberately leaves source characters intact; preserve only these attachments.
  // Standard fixing can extend to the complete paragraph, including pills outside the edit.
  NSRange fixingRange = [_backing.string paragraphRangeForRange:range];
  NSMutableArray<NSDictionary *> *pills = [NSMutableArray new];
  [_backing enumerateAttribute:NSAttachmentAttributeName
                       inRange:fixingRange
                       options:0
                    usingBlock:^(id value, NSRange subrange, BOOL *stop) {
                      if ([value isKindOfClass:ENRMLinkPillAttachment.class])
                        [pills addObject:@{@"attachment" : value, @"range" : [NSValue valueWithRange:subrange]}];
                    }];
  [_backing fixAttributesInRange:range];
  for (NSDictionary *pill in pills)
    [_backing addAttribute:NSAttachmentAttributeName value:pill[@"attachment"] range:[pill[@"range"] rangeValue]];
  // Fixing belongs to the existing edit notification. Direct backing restoration avoids recursive edits.
}
@end

UITextView *ENRMCreateMarkdownTextView(void)
{
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] init];
  NSLayoutManager *manager = [[NSLayoutManager alloc] init];
  manager.delegate = ENRMLinkPillLayoutDelegate.shared;
  [storage addLayoutManager:manager];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];
  [manager addTextContainer:container];
  return [[UITextView alloc] initWithFrame:CGRectZero textContainer:container];
}
#endif

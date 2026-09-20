#import "ENRMLinkPillAttachment.h"
#import "ENRMLinkPillIconCache.h"
#import "ENRMLinkPillTextStorage.h"
#import "StyleConfig.h"

#if !TARGET_OS_OSX

@implementation ENRMLinkPillAttachment {
  NSString *_label;
  LinkVariantConfig *_variant;
  UIFont *_font;
  UIImage *_icon;
}

- (instancetype)initWithLabel:(NSString *)originalLabel variant:(LinkVariantConfig *)variant font:(UIFont *)font
{
  self = [super initWithData:nil ofType:nil];
  if (self) {
    _variant = variant;
    _font = font ?: [UIFont systemFontOfSize:16];
    NSString *label = variant.label.length > 0 ? variant.label : originalLabel;
    _label = [[label stringByReplacingOccurrencesOfString:@"\n"
                                               withString:@" "] stringByReplacingOccurrencesOfString:@"\r"
                                                                                          withString:@" "];
    _icon = ENRMLoadLinkPillIcon(variant.iconUri);
  }
  return self;
}

- (CGFloat)boxHeight
{
  return ceil(_font.ascender - _font.descender + 2 * (_variant.paddingVertical + _variant.borderWidth));
}

- (CGFloat)widthForLimit:(CGFloat)available
{
  CGFloat iconWidth = _icon ? _font.pointSize * 1.25 : 0;
  CGFloat natural = ceil([_label sizeWithAttributes:@{NSFontAttributeName : _font}].width + iconWidth +
                         2 * (_variant.paddingHorizontal + _variant.borderWidth));
  CGFloat limit = _variant.maxWidth > 0 ? MIN(available, _variant.maxWidth) : available;
  return MAX(1, MIN(natural, limit));
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)container
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  // Use the full container width, not the remainder of the current line. TextKit then moves
  // the whole attachment to the next line if it doesn't fit the remainder.
  NSParagraphStyle *paragraph = [container.layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                                                       atIndex:characterIndex
                                                                effectiveRange:NULL];
  CGFloat indent = MAX(paragraph.firstLineHeadIndent, paragraph.headIndent);
  CGFloat tailInset = paragraph.tailIndent < 0 ? -paragraph.tailIndent : 0;
  CGFloat available = MAX(1, container.size.width - 2 * container.lineFragmentPadding - indent - tailInset);
  CGFloat inset = _variant.paddingVertical + _variant.borderWidth;
  return CGRectMake(0, _font.descender - inset, [self widthForLimit:available], self.boxHeight);
}

- (UIImage *)imageForBounds:(CGRect)bounds textContainer:(NSTextContainer *)container characterIndex:(NSUInteger)index
{
  CGSize size = bounds.size;
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    CGRect rect = (CGRect){CGPointZero, size};
    UIBezierPath *background = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:_variant.borderRadius];
    [_variant.backgroundColor ?: UIColor.clearColor setFill];
    [background fill];
    if (_variant.borderWidth > 0) {
      UIBezierPath *border =
          [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, _variant.borderWidth / 2, _variant.borderWidth / 2)
                                     cornerRadius:_variant.borderRadius];
      border.lineWidth = _variant.borderWidth;
      [_variant.borderColor setStroke];
      [border stroke];
    }
    [background addClip];
    CGFloat left = _variant.paddingHorizontal + _variant.borderWidth;
    CGFloat right = size.width - left;
    if (_icon && right - left >= _font.pointSize) {
      CGFloat side = _font.pointSize;
      CGFloat scale = side / MAX(_icon.size.width, _icon.size.height);
      CGSize iconSize = CGSizeMake(_icon.size.width * scale, _icon.size.height * scale);
      CGRect iconRect = CGRectMake(left + (side - iconSize.width) / 2, (size.height - iconSize.height) / 2,
                                   iconSize.width, iconSize.height);
      [_icon drawInRect:iconRect];
      left += side * 1.25;
    }
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{
      NSFontAttributeName : _font,
      NSForegroundColorAttributeName : _variant.color,
      NSUnderlineStyleAttributeName : @(_variant.underline ? NSUnderlineStyleSingle : NSUnderlineStyleNone),
      NSParagraphStyleAttributeName : paragraph,
    };
    [_label drawInRect:CGRectMake(left, _variant.paddingVertical + _variant.borderWidth, MAX(0, right - left),
                                  size.height)
        withAttributes:attributes];
  }];
}
@end

@implementation ENRMLinkPillLayoutDelegate
+ (instancetype)shared
{
  static ENRMLinkPillLayoutDelegate *delegate;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ delegate = [[self alloc] init]; });
  return delegate;
}

- (NSUInteger)layoutManager:(NSLayoutManager *)manager
       shouldGenerateGlyphs:(const CGGlyph *)glyphs
                 properties:(const NSGlyphProperty *)properties
           characterIndexes:(const NSUInteger *)indexes
                       font:(UIFont *)font
              forGlyphRange:(NSRange)glyphRange
{
  NSUInteger count = glyphRange.length;
  NSMutableData *glyphData = [NSMutableData dataWithBytes:glyphs length:count * sizeof(CGGlyph)];
  NSMutableData *propertyData = [NSMutableData dataWithBytes:properties length:count * sizeof(NSGlyphProperty)];
  CGGlyph *replacement = glyphData.mutableBytes;
  NSGlyphProperty *replacementProperties = propertyData.mutableBytes;
  BOOL changed = NO;
  for (NSUInteger i = 0; i < count; i++) {
    NSRange range;
    // Attribute runs may split at every source character after UIKit fixes fonts/colors.
    // The pill starts at the longest range of the attachment alone, not the current run.
    id attachment = [manager.textStorage attribute:NSAttachmentAttributeName
                                           atIndex:indexes[i]
                             longestEffectiveRange:&range
                                           inRange:NSMakeRange(0, manager.textStorage.length)];
    if (![attachment isKindOfClass:ENRMLinkPillAttachment.class])
      continue;
    changed = YES;
    // A character can have multiple glyphs, even across font/callback boundaries.
    // The preceding glyph is outside this callback's range and is already generated.
    BOOL startsAttachment = indexes[i] == range.location;
    BOOL continuesCharacter =
        startsAttachment && (i > 0 ? indexes[i - 1] == indexes[i]
                                   : glyphRange.location > 0 &&
                                         [manager characterIndexForGlyphAtIndex:glyphRange.location - 1] == indexes[i]);
    if (startsAttachment && !continuesCharacter) {
      // TextKit's attachment glyph exists only in the glyph buffer, never in text storage.
      replacement[i] = 0xFFFC;
      replacementProperties[i] = 0;
    } else {
      replacement[i] = 0;
      replacementProperties[i] = NSGlyphPropertyNull;
    }
  }
  if (!changed)
    return 0;
  [manager setGlyphs:replacement
            properties:replacementProperties
      characterIndexes:indexes
                  font:font
         forGlyphRange:glyphRange];
  return count;
}

- (BOOL)layoutManager:(NSLayoutManager *)manager shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)index
{
  if (index >= manager.textStorage.length)
    return YES;
  NSRange range;
  id attachment = [manager.textStorage attribute:NSAttachmentAttributeName
                                         atIndex:index
                           longestEffectiveRange:&range
                                         inRange:NSMakeRange(0, manager.textStorage.length)];
  return ![attachment isKindOfClass:ENRMLinkPillAttachment.class] || index == range.location;
}
@end

static NSLayoutManager *ENRMPillLayout(NSAttributedString *text, CGSize size, NSTextStorage **storageOut,
                                       NSTextContainer **containerOut)
{
  NSTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *manager = [[NSLayoutManager alloc] init];
  manager.delegate = ENRMLinkPillLayoutDelegate.shared;
  manager.allowsNonContiguousLayout = NO;
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:size];
  container.lineFragmentPadding = 0;
  [storage addLayoutManager:manager];
  [manager addTextContainer:container];
  [manager ensureLayoutForTextContainer:container];
  *storageOut = storage;
  *containerOut = container;
  return manager;
}

static BOOL ENRMHasLinkPill(NSAttributedString *text)
{
  __block BOOL found = NO;
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:ENRMLinkPillAttachment.class]) {
                    found = YES;
                    *stop = YES;
                  }
                }];
  return found;
}

CGRect ENRMLinkPillTextBounds(NSAttributedString *text, CGFloat width)
{
  if (!ENRMHasLinkPill(text))
    return [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              context:nil];
  // NSLayoutManager does not own its storage. Keep it alive through measurement/drawing under ARC.
  __attribute__((objc_precise_lifetime)) NSTextStorage *storage;
  NSTextContainer *container;
  NSLayoutManager *manager = ENRMPillLayout(text, CGSizeMake(width, CGFLOAT_MAX), &storage, &container);
  return [manager usedRectForTextContainer:container];
}

void ENRMDrawLinkPillText(NSAttributedString *text, CGRect rect)
{
  if (!ENRMHasLinkPill(text)) {
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    return;
  }
  // NSLayoutManager does not own its storage. Keep it alive through measurement/drawing under ARC.
  __attribute__((objc_precise_lifetime)) NSTextStorage *storage;
  NSTextContainer *container;
  NSLayoutManager *manager = ENRMPillLayout(text, rect.size, &storage, &container);
  NSRange glyphs = [manager glyphRangeForTextContainer:container];
  [manager drawBackgroundForGlyphRange:glyphs atPoint:rect.origin];
  [manager drawGlyphsForGlyphRange:glyphs atPoint:rect.origin];
}
#endif

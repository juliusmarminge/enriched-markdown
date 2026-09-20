#import "ENRMLinkPillIconCache.h"
#if !TARGET_OS_OSX
#import <ImageIO/ImageIO.h>

UIImage *ENRMLoadLinkPillIcon(NSString *iconUri)
{
  NSURL *uri = iconUri.length > 0 ? [NSURL URLWithString:iconUri] : nil;
  if (!uri.isFileURL)
    return nil;
  NSString *path = uri.URLByResolvingSymlinksInPath.path;
  NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
  if (!attributes || ![attributes[NSFileType] isEqual:NSFileTypeRegular])
    return nil;
  NSString *key =
      [NSString stringWithFormat:@"%@|%.9f|%@", path, [attributes[NSFileModificationDate] timeIntervalSince1970],
                                 attributes[NSFileSize]];
  static NSMutableDictionary<NSString *, UIImage *> *images;
  static NSMutableArray<NSString *> *order;
  static NSUInteger bytes;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    images = [NSMutableDictionary new];
    order = [NSMutableArray new];
  });
  @synchronized(images) {
    UIImage *cached = images[key];
    if (cached) {
      [order removeObject:key];
      [order addObject:key];
      return cached;
    }
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!source)
      return nil;
    NSDictionary *options = @{
      (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
      (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
      (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @YES,
      (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize : @512,
    };
    CGImageRef decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!decoded)
      return nil;
    NSUInteger cost = CGImageGetBytesPerRow(decoded) * CGImageGetHeight(decoded);
    UIImage *image = [UIImage imageWithCGImage:decoded];
    CGImageRelease(decoded);
    if (cost > 8 * 1024 * 1024)
      return image;
    images[key] = image;
    [order addObject:key];
    bytes += cost;
    while (order.count > 64 || bytes > 8 * 1024 * 1024) {
      NSString *oldest = order.firstObject;
      CGImageRef previous = images[oldest].CGImage;
      bytes -= CGImageGetBytesPerRow(previous) * CGImageGetHeight(previous);
      [images removeObjectForKey:oldest];
      [order removeObjectAtIndex:0];
    }
    return image;
  }
}
#endif

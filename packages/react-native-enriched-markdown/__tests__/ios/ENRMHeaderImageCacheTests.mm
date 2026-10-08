#import "../../ios/utils/ENRMImageDownloader.h"
#import <XCTest/XCTest.h>

@interface ENRMHeaderImageCacheTests : XCTestCase
@end
@implementation ENRMHeaderImageCacheTests
- (void)testHeaderNamesHaveCaseInsensitiveIdentity
{
  XCTAssertEqualObjects(
      ENRMImageCacheKey(@"https://example.com/image", @{@"Authorization" : @"token", @"Accept" : @"image/png"}),
      ENRMImageCacheKey(@"https://example.com/image", @{@"accept" : @"image/png", @"authorization" : @"token"}));
}
- (void)testHeaderValuesAndURLsRemainSeparate
{
  NSString *url = @"https://example.com/image";
  XCTAssertNotEqualObjects(ENRMImageCacheKey(url, @{@"Authorization" : @"one"}),
                           ENRMImageCacheKey(url, @{@"Authorization" : @"two"}));
  XCTAssertNotEqualObjects(ENRMImageCacheKey(url, @{@"Authorization" : @"one"}),
                           ENRMImageCacheKey(@"https://example.com/other", @{@"Authorization" : @"one"}));
  XCTAssertEqualObjects(ENRMImageCacheKey(url, nil), url);
  XCTAssertFalse([ENRMImageCacheKey(url, @{@"Authorization" : @"secret-value"}) containsString:@"secret-value"]);
}
- (void)testHeaderRequestsCannotConsultTheSharedHTTPCache
{
  ENRMImageDownloader *downloader = [[ENRMImageDownloader alloc] init];
  NSURLSession *ordinary = [downloader valueForKey:@"session"];
  NSURLSession *headers = [downloader valueForKey:@"headerSession"];
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/cache-test"]];
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:@{@"Cache-Control" : @"max-age=3600"}];
  NSCachedURLResponse *cached =
      [[NSCachedURLResponse alloc] initWithResponse:response
                                               data:[@"cached response" dataUsingEncoding:NSUTF8StringEncoding]];
  [ordinary.configuration.URLCache storeCachedResponse:cached forRequest:request];
  XCTAssertNotNil([ordinary.configuration.URLCache cachedResponseForRequest:request]);
  XCTAssertNil([headers.configuration.URLCache cachedResponseForRequest:request]);
  XCTAssertEqual(headers.configuration.requestCachePolicy, NSURLRequestReloadIgnoringLocalCacheData);
  [ordinary.configuration.URLCache removeCachedResponseForRequest:request];
  [ordinary invalidateAndCancel];
  [headers invalidateAndCancel];
}
@end

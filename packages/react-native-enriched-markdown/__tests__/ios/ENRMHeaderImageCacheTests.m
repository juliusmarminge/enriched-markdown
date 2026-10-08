#import "../../ios/utils/ENRMImageDownloader.h"
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

static NSUInteger requestCount;
static NSString *lastAuthorization;
@interface ENRMImageTestProtocol : NSURLProtocol
@end
@implementation ENRMImageTestProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
  return [request.URL.host isEqualToString:@"enrm-cache.test"];
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
  return request;
}
- (void)startLoading
{
  requestCount++;
  lastAuthorization = [self.request valueForHTTPHeaderField:@"Authorization"];
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(2, 2)];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [UIColor.redColor setFill];
    [context fillRect:CGRectMake(0, 0, 2, 2)];
  }];
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:@{@"Content-Type" : @"image/png"}];
  [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
  [self.client URLProtocol:self didLoadData:UIImagePNGRepresentation(image)];
  [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading
{
}
@end

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
- (void)testRequestHeadersAndDecodedCacheUseTheSameCaseInsensitiveIdentity
{
  ENRMImageDownloader *downloader = [[ENRMImageDownloader alloc] init];
  NSURLSession *original = [downloader valueForKey:@"headerSession"];
  NSURLSessionConfiguration *configuration = original.configuration;
  configuration.protocolClasses = @[ ENRMImageTestProtocol.class ];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  [downloader setValue:session forKey:@"headerSession"];
  [original invalidateAndCancel];
  requestCount = 0;
  lastAuthorization = nil;
  NSString *url = [@"https://enrm-cache.test/" stringByAppendingString:NSUUID.UUID.UUIDString];
  XCTestExpectation *first = [self expectationWithDescription:@"First header-bearing image"];
  [downloader downloadURL:url
                  headers:@{@"Authorization" : @"first", @"authorization" : @"second"}
               completion:^(UIImage *image) {
                 XCTAssertNotNil(image);
                 [first fulfill];
               }];
  [self waitForExpectations:@[ first ] timeout:5];
  XCTAssertEqualObjects(lastAuthorization, @"second");
  XCTestExpectation *cached = [self expectationWithDescription:@"Equivalent headers use decoded image cache"];
  [downloader downloadURL:url
                  headers:@{@"authorization" : @"second"}
               completion:^(UIImage *image) {
                 XCTAssertNotNil(image);
                 [cached fulfill];
               }];
  [self waitForExpectations:@[ cached ] timeout:5];
  XCTAssertEqual(requestCount, 1u);
  [session invalidateAndCancel];
  [[downloader valueForKey:@"session"] invalidateAndCancel];
}
@end

#pragma once
#import "ImageRequestHeaderUtils.h"
#import "MarkdownASTNode.h"

// Annotates only transport on the accepted AST. The manifest owns occurrence identity.
FOUNDATION_EXPORT void ENRMPrepareImageSources(MarkdownASTNode *ast, NSArray<NSDictionary *> *assets, BOOL enabled,
                                               BOOL decisionsAccepted, NSDictionary *sources);
FOUNDATION_EXPORT NSDictionary *ENRMImageSourceDecisionForNode(MarkdownASTNode *node);
// Render signatures include transport state without changing semantic AST signatures.
FOUNDATION_EXPORT uint64_t ENRMImageSourceSignatureForNode(MarkdownASTNode *node);
FOUNDATION_EXPORT uint64_t ENRMImageSourceSignatureForNodes(NSArray<MarkdownASTNode *> *nodes);
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *ENRMMergeImageRequestHeaders(NSDictionary *documentHeaders,
                                                                                     NSDictionary *sourceHeaders);

#ifdef __cplusplus
#include <functional>
#include <string>
#include <type_traits>
#include <utility>
template <typename T, typename = void> struct ENRMHasImageSources : std::false_type {};
template <typename T>
struct ENRMHasImageSources<T, std::void_t<decltype(std::declval<T>().imageSources)>> : std::true_type {};

template <typename PropsT> static inline NSDictionary *ENRMImageSourcesFromProps(const PropsT &props)
{
  NSMutableDictionary *sources = [NSMutableDictionary dictionary];
  for (const auto &item : props.imageSources) {
    sources[@(item.id.c_str())] = @{
      @"id" : @(item.id.c_str()),
      @"url" : @(item.url.c_str()),
      @"anchor" : @(item.anchor.c_str()),
      @"uri" : @(item.uri.c_str()),
      @"useDefault" : @(item.useDefault),
      @"headers" : ENRMImageRequestHeadersFromProps(item.headers) ?: @{}
    };
  }
  return sources;
}

template <typename PropsT> static inline BOOL ENRMImageSourcesAccepted(const PropsT &props)
{
  return props.imageSourcesRevision >= props.imageSourcesContinuityStart &&
         props.imageSourcesRevision <= props.documentRevision;
}

template <typename PropsT> static inline size_t ENRMImageSourcesFingerprint(const PropsT &props)
{
  size_t hash = 0;
  if constexpr (ENRMHasImageSources<PropsT>::value) {
    auto mix = [&](size_t value) { hash ^= value + 0x9e3779b9 + (hash << 6) + (hash >> 2); };
    mix(std::hash<bool>{}(props.enableImageSourceResolution));
    for (const auto &header : props.imageRequestHeaders) {
      mix(std::hash<std::string>{}(header.name));
      mix(std::hash<std::string>{}(header.value));
    }
    mix(std::hash<int>{}(props.documentRevision));
    mix(std::hash<int>{}(props.imageSourcesRevision));
    mix(std::hash<int>{}(props.imageSourcesContinuityStart));
    for (const auto &item : props.imageSources) {
      mix(std::hash<std::string>{}(item.id));
      mix(std::hash<std::string>{}(item.url));
      mix(std::hash<std::string>{}(item.anchor));
      mix(std::hash<std::string>{}(item.uri));
      mix(std::hash<bool>{}(item.useDefault));
      for (const auto &header : item.headers) {
        mix(std::hash<std::string>{}(header.name));
        mix(std::hash<std::string>{}(header.value));
      }
    }
  }
  return hash;
}
#endif

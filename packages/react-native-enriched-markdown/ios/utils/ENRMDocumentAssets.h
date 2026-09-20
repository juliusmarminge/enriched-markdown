#pragma once
#import "MarkdownASTNode.h"
#import "StyleConfig.h"
#import <Foundation/Foundation.h>

// Traverses the accepted native AST in source order. IDs identify occurrences,
// including links, so duplicate URLs remain independent.
FOUNDATION_EXPORT NSArray<NSDictionary *> *ENRMPrepareDocumentAssets(MarkdownASTNode *ast, BOOL enableMediaSlots,
                                                                     BOOL decisionsAccepted, NSDictionary *overrides);
FOUNDATION_EXPORT CGFloat ENRMMediaSlotHeight(MarkdownASTNode *node, CGFloat width, StyleConfig *config);

#ifdef __cplusplus
#include <cmath>
#include <functional>
#include <string>
#include <type_traits>
#include <utility>
template <typename T, typename = void> struct ENRMHasMediaSlots : std::false_type {};
template <typename T>
struct ENRMHasMediaSlots<T, std::void_t<decltype(std::declval<T>().mediaOverrides)>> : std::true_type {};

template <typename PropsT> static inline NSDictionary *ENRMMediaOverridesFromProps(const PropsT &props)
{
  NSMutableDictionary *overrides = [NSMutableDictionary dictionary];
  for (const auto &item : props.mediaOverrides) {
    if (!std::isfinite(item.height) || item.height < 0 || !std::isfinite(item.width) || item.width < 0)
      continue;
    NSString *identifier = [[NSString alloc] initWithUTF8String:item.id.c_str()];
    overrides[identifier] = @{
      @"height" : @(item.height),
      @"width" : @(item.width),
      @"url" : [[NSString alloc] initWithUTF8String:item.url.c_str()],
      @"kind" : [[NSString alloc] initWithUTF8String:item.kind.c_str()],
      @"anchor" : [[NSString alloc] initWithUTF8String:item.anchor.c_str()]
    };
  }
  return overrides;
}

template <typename PropsT> static inline size_t ENRMMediaPropsFingerprint(const PropsT &props)
{
  size_t hash = 0;
  if constexpr (ENRMHasMediaSlots<PropsT>::value) {
    auto mix = [&](size_t value) { hash ^= value + 0x9e3779b9 + (hash << 6) + (hash >> 2); };
    mix(std::hash<bool>{}(props.enableMediaSlots));
    mix(std::hash<int>{}(props.documentRevision));
    mix(std::hash<int>{}(props.mediaOverridesRevision));
    for (const auto &item : props.mediaOverrides) {
      mix(std::hash<std::string>{}(item.id));
      mix(std::hash<std::string>{}(item.url));
      mix(std::hash<std::string>{}(item.kind));
      mix(std::hash<std::string>{}(item.anchor));
      mix(std::hash<float>{}(item.height));
      mix(std::hash<float>{}(item.width));
    }
  }
  return hash;
}
#endif

#ifdef __cplusplus
template <typename PropsT> static inline bool ENRMMediaSlotsEnabled(const PropsT &props)
{
  if constexpr (ENRMHasMediaSlots<PropsT>::value)
    return props.enableMediaSlots;
  return false;
}
#endif

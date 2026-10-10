#pragma once

#import "ENRMLinkRegexConfig.h"
#import "MarkdownASTNode.h"

#ifdef __cplusplus
extern "C" {
#endif

// Mutates only the freshly parsed AST. Existing links and block code are opaque.
void ENRMRecognizeTextLinks(MarkdownASTNode *ast, ENRMLinkRegexConfig *linkRegex,
                            ENRMLinkRegexConfig *inlineCodeLinkRegex);

/// Cached per pattern; thread-safe.
ENRMLinkRegexConfig *ENRMCachedTextLinkRegexConfig(NSString *pattern, BOOL caseInsensitive, BOOL dotAll);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
// Props share EnrichedMarkdownTextInput's native regex transport.
template <typename RegexProps>
static inline ENRMLinkRegexConfig *ENRMTextLinkRegexConfigFromProps(const RegexProps &props)
{
  if (props.isDisabled || props.isDefault || props.pattern.empty())
    return nil;
  return ENRMCachedTextLinkRegexConfig([NSString stringWithUTF8String:props.pattern.c_str()], props.caseInsensitive,
                                       props.dotAll);
}

template <typename RegexProps>
static inline BOOL ENRMTextLinkRegexPropsEqual(const RegexProps &oldProps, const RegexProps &newProps)
{
  return oldProps.isDisabled == newProps.isDisabled && oldProps.isDefault == newProps.isDefault &&
         oldProps.caseInsensitive == newProps.caseInsensitive && oldProps.dotAll == newProps.dotAll &&
         oldProps.pattern == newProps.pattern;
}
#endif

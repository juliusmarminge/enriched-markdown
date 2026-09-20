#pragma once

#include <folly/dynamic.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/core/propsConversions.h>

namespace facebook::react {

#ifdef RN_SERIALIZABLE_STATE
inline folly::dynamic toDynamic(const EnrichedMarkdownTextProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdown"] = props.markdown;
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["streamingAnimation"] = props.streamingAnimation;
  serializedProps["numberOfLines"] = props.numberOfLines;
  serializedProps["ellipsizeMode"] = props.ellipsizeMode;

  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  return serializedProps;
}

inline folly::dynamic toDynamic(const EnrichedMarkdownProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdown"] = props.markdown;
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["streamingAnimation"] = props.streamingAnimation;

  serializedProps["enableImageSourceResolution"] = props.enableImageSourceResolution;
  serializedProps["imageSourcesRevision"] = props.imageSourcesRevision;
  serializedProps["imageSourcesContinuityStart"] = props.imageSourcesContinuityStart;
  folly::dynamic imageSources = folly::dynamic::array();
  for (const auto &source : props.imageSources) {
    folly::dynamic headers = folly::dynamic::array();
    for (const auto &header : source.headers) {
      headers.push_back(folly::dynamic::object("name", header.name)("value", header.value));
    }
    imageSources.push_back(folly::dynamic::object("id", source.id)("url", source.url)("anchor", source.anchor)(
        "uri", source.uri)("headers", std::move(headers))("useDefault", source.useDefault));
  }
  serializedProps["imageSources"] = std::move(imageSources);
  serializedProps["documentRevision"] = props.documentRevision;
  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  return serializedProps;
}

inline folly::dynamic toDynamic(const EnrichedMarkdownTextInputProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["defaultValue"] = props.defaultValue;
  serializedProps["placeholder"] = props.placeholder;
  serializedProps["fontSize"] = props.fontSize;
  serializedProps["fontWeight"] = props.fontWeight;
  serializedProps["fontFamily"] = props.fontFamily;
  serializedProps["lineHeight"] = props.lineHeight;

  return serializedProps;
}
#endif

} // namespace facebook::react

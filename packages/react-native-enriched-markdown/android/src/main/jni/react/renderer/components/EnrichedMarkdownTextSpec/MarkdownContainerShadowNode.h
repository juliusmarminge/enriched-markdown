#pragma once

#include "MarkdownContainerMeasurementManager.h"
#include "MarkdownTextState.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownContainerComponentName[];

class MarkdownContainerShadowNode final
    : public ConcreteViewShadowNode<MarkdownContainerComponentName, EnrichedMarkdownProps, EnrichedMarkdownEventEmitter,
                                    MarkdownTextState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  MarkdownContainerShadowNode(ShadowNode const &sourceShadowNode, ShadowNodeFragment const &fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment) {
    dirtyLayoutIfNeeded();
    const auto &oldProps = static_cast<const MarkdownContainerShadowNode &>(sourceShadowNode).getConcreteProps();
    const auto &props = getConcreteProps();
    if (oldProps.enableImageSourceResolution != props.enableImageSourceResolution ||
        oldProps.imageSourcesRevision != props.imageSourcesRevision ||
        oldProps.imageSourcesContinuityStart != props.imageSourcesContinuityStart ||
        oldProps.imageSources != props.imageSources) {
      dirtyLayout();
    }
  }

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurementsManager(const std::shared_ptr<MarkdownContainerMeasurementManager> &measurementsManager);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

private:
  int forceHeightRecalculationCounter_{0};
  std::shared_ptr<MarkdownContainerMeasurementManager> measurementsManager_;
};

} // namespace facebook::react

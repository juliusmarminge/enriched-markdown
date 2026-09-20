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
    const auto &previousProps = static_cast<const MarkdownContainerShadowNode &>(sourceShadowNode).getConcreteProps();
    const auto &props = getConcreteProps();
    if (previousProps.documentRevision != props.documentRevision ||
        previousProps.enableMediaSlots != props.enableMediaSlots ||
        previousProps.mediaOverridesRevision != props.mediaOverridesRevision ||
        previousProps.mediaOverrides != props.mediaOverrides) {
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

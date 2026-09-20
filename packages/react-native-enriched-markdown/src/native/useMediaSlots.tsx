import { useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import type { LayoutChangeEvent, NativeSyntheticEvent } from 'react-native';
import type {
  DocumentAssetsEventInternal,
  MediaLayoutEventInternal,
  MediaFrameInternal,
} from '../EnrichedMarkdownNativeComponent';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps';
import type { MarkdownDocumentAsset, MarkdownMediaAsset } from '../types/media';
import {
  acceptMediaMeasurement,
  mediaOverrideForFrame,
  sameMediaSize,
  validMediaFrames,
} from '../mediaSlotState';
import type { MediaMeasurement } from '../mediaSlotState';

type NativeAsset = MarkdownDocumentAsset & { anchor: string };
type Manifest = { revision: number; assets: NativeAsset[] };
type MediaLayout = MediaLayoutEventInternal & {
  identities: Record<string, string>;
};
const stripAnchor = <T extends NativeAsset>({ anchor: _anchor, ...asset }: T) =>
  asset;
const identity = (asset: NativeAsset) =>
  JSON.stringify([
    asset.id,
    asset.kind,
    asset.url,
    asset.anchor,
    asset.eligible,
  ]);
const identities = (assets: NativeAsset[]) =>
  Object.fromEntries(assets.map((asset) => [asset.id, identity(asset)]));

export function useMediaSlots(
  markdown: string,
  parserKey: string,
  renderMedia: EnrichedMarkdownTextProps['renderMedia'],
  onDocumentAssets: EnrichedMarkdownTextProps['onDocumentAssets']
) {
  const document = useRef({
    markdown,
    parserKey,
    revision: 1,
    continuityStart: 1,
    generation: 0,
  });
  if (
    document.current.markdown !== markdown ||
    document.current.parserKey !== parserKey
  ) {
    const previous = document.current;
    const append =
      previous.parserKey === parserKey &&
      previous.markdown.length > 0 &&
      markdown.length > previous.markdown.length &&
      markdown.startsWith(previous.markdown);
    document.current = {
      markdown,
      parserKey,
      revision: previous.revision + 1,
      continuityStart: append
        ? previous.continuityStart
        : previous.revision + 1,
      generation: previous.generation + (append ? 0 : 1),
    };
  }
  const { revision, continuityStart, generation } = document.current;
  const [manifest, setManifest] = useState<Manifest>();
  const acceptedManifest = useRef<Manifest | undefined>(undefined);
  const [layout, setLayout] = useState<MediaLayout>();
  const latestLayout = useRef<MediaLayout | undefined>(undefined);
  const pendingLayout = useRef<MediaLayoutEventInternal | undefined>(undefined);
  const [origin, setOrigin] = useState({ x: 0, y: 0 });
  const [measurements, setMeasurements] = useState<
    Record<string, MediaMeasurement & { identity: string; generation: number }>
  >({});
  const reported = useRef(-1);
  // Only uninterrupted appends with identical parser inputs retain prior data.
  // Native revalidates each carried decision against the newly accepted AST.
  const assets =
    manifest && manifest.revision >= continuityStart ? manifest.assets : [];
  const frames =
    layout && layout.revision >= continuityStart ? layout.frames : [];
  const frameForAsset = (asset: NativeAsset) =>
    layout?.identities[asset.id] === identity(asset)
      ? frames.find((entry) => entry.id === asset.id)
      : undefined;
  const rendered = assets.flatMap((asset) => {
    if (asset.kind === 'link' || !asset.eligible || !renderMedia) return [];
    const content = renderMedia(stripAnchor(asset));
    if (content == null || typeof content === 'boolean') return [];
    return [{ asset, content }];
  });
  const overrides = rendered.map(({ asset }) => {
    const measurement = measurements[asset.id];
    const box = mediaOverrideForFrame(
      asset.id,
      frameForAsset(asset),
      measurement?.identity === identity(asset) &&
        measurement.generation === generation
        ? measurement
        : undefined
    );
    return {
      id: box.id,
      height: box.height,
      width: box.width,
      url: asset.url,
      kind: asset.kind,
      anchor: asset.anchor,
    };
  });

  const onNativeDocumentAssets = (
    event: NativeSyntheticEvent<DocumentAssetsEventInternal>
  ) => {
    if (event.nativeEvent.revision !== document.current.revision) return;
    const next = event.nativeEvent as unknown as Manifest;
    acceptedManifest.current = next;
    setManifest((previous) =>
      previous?.revision === next.revision &&
      JSON.stringify(previous.assets) === JSON.stringify(next.assets)
        ? previous
        : next
    );
    // A frame can arrive before its manifest. Stamp only frames of this exact
    // revision; older frames keep their original occurrence identities.
    const received =
      pendingLayout.current?.revision === next.revision
        ? pendingLayout.current
        : latestLayout.current?.revision === next.revision
          ? latestLayout.current
          : undefined;
    if (received) {
      const updated = { ...received, identities: identities(next.assets) };
      latestLayout.current = updated;
      pendingLayout.current = undefined;
      setLayout(updated);
    }
    if (reported.current !== next.revision) {
      reported.current = next.revision;
      onDocumentAssets?.({
        revision: next.revision,
        assets: next.assets.map(stripAnchor) as MarkdownDocumentAsset[],
      });
    }
  };
  const onNativeMediaLayout = (
    event: NativeSyntheticEvent<MediaLayoutEventInternal>
  ) => {
    const next = event.nativeEvent;
    if (next.revision !== document.current.revision) return;
    const valid = validMediaFrames(next.frames);
    const current = acceptedManifest.current;
    if (current?.revision !== next.revision) {
      // Keep mounted slots until the accepted manifest can identify new frames.
      pendingLayout.current = { revision: next.revision, frames: valid };
      return;
    }
    const nextLayout = {
      revision: next.revision,
      frames: valid,
      identities:
        current?.revision === next.revision ? identities(current.assets) : {},
    };
    latestLayout.current = nextLayout;
    setLayout((previous) => {
      if (
        previous?.revision === next.revision &&
        JSON.stringify(previous.identities) ===
          JSON.stringify(nextLayout.identities) &&
        previous.frames.length === valid.length &&
        previous.frames.every((frame, index) => {
          const other = valid[index]!;
          return (
            frame.id === other.id &&
            sameMediaSize(frame.x, other.x) &&
            sameMediaSize(frame.y, other.y) &&
            sameMediaSize(frame.width, other.width) &&
            sameMediaSize(frame.height, other.height)
          );
        })
      )
        return previous;
      return nextLayout;
    });
  };
  const onNativeLayout = ({ nativeEvent }: LayoutChangeEvent) => {
    const { x, y } = nativeEvent.layout;
    setOrigin((previous) =>
      sameMediaSize(previous.x, x) && sameMediaSize(previous.y, y)
        ? previous
        : { x, y }
    );
  };
  const onSlotLayout = (
    asset: NativeAsset & MarkdownMediaAsset,
    frame: MediaFrameInternal,
    event: LayoutChangeEvent
  ) => {
    const { width, height } = event.nativeEvent.layout;
    const next = { id: asset.id, width, height };
    setMeasurements((previous) => {
      const current = acceptedManifest.current;
      const currentAsset = current?.assets.find(
        (entry) => entry.id === asset.id
      );
      if (
        !current ||
        current.revision < document.current.continuityStart ||
        !currentAsset ||
        identity(currentAsset) !== identity(asset) ||
        !acceptMediaMeasurement(
          revision,
          document.current.revision,
          pendingLayout.current?.revision === revision
            ? pendingLayout.current.frames.find(
                (entry) => entry.id === frame.id
              )
            : latestLayout.current?.identities[asset.id] === identity(asset) &&
                latestLayout.current.revision >=
                  document.current.continuityStart
              ? latestLayout.current.frames.find(
                  (entry) => entry.id === frame.id
                )
              : undefined,
          next,
          previous[asset.id]?.identity === identity(asset) &&
            previous[asset.id]?.generation === generation
            ? previous[asset.id]
            : undefined
        )
      )
        return previous;
      return {
        ...previous,
        [asset.id]: { ...next, identity: identity(asset), generation },
      };
    });
  };

  const slots = rendered.map(({ asset, content }) => {
    const frame = frameForAsset(asset);
    if (!frame) return null;
    return (
      <View
        key={`${generation}:${identity(asset)}`}
        collapsable={false}
        style={[
          styles.slot,
          {
            left: origin.x + frame.x,
            top: origin.y + frame.y,
            width: frame.width,
          },
        ]}
        onLayout={(event) => onSlotLayout(asset, frame, event)}
      >
        {content}
      </View>
    );
  });
  return {
    slots,
    onNativeLayout,
    nativeProps: {
      documentRevision: revision,
      enableDocumentAssets: !!renderMedia || !!onDocumentAssets,
      enableMediaSlots: !!renderMedia,
      mediaOverridesRevision:
        manifest && manifest.revision >= continuityStart
          ? manifest.revision
          : -1,
      mediaOverrides: overrides,
      onDocumentAssets: onNativeDocumentAssets,
      onMediaLayout: onNativeMediaLayout,
    },
  };
}

const styles = StyleSheet.create({ slot: { position: 'absolute' } });

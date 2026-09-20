import { useEffect, useRef, useState } from 'react';
import { ImageSourceState } from '../imageSourceState';
import type { NativeImageAsset } from '../imageSourceState';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps';

export function useImageSources(
  resolver: EnrichedMarkdownTextProps['resolveImageSource'],
  continuityStart: number,
  assetsRevision: number,
  assets: NativeImageAsset[]
) {
  const state = useRef<ImageSourceState | undefined>(undefined);
  if (!state.current) state.current = new ImageSourceState();
  const current = state.current;
  const [, refresh] = useState(0);
  current.configure(resolver, continuityStart, assets);
  // Reconcile after every commit. Configure deduplicates layout-only renders.
  useEffect(() => {
    current.configure(resolver, continuityStart, assets);
    current.start(() => refresh((value) => value + 1));
  });
  useEffect(() => () => current.stop(), [current]);
  return {
    enableImageSourceResolution: !!resolver,
    imageSourcesContinuityStart: resolver ? continuityStart : 1,
    imageSourcesRevision: resolver ? assetsRevision : -1,
    imageSources: current.sources(),
  };
}

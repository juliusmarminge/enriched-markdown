import { useRef, useState } from 'react';
import { useImageSources } from './useImageSources';
import type { NativeImageAsset } from '../imageSourceState';
import type { NativeSyntheticEvent } from 'react-native';
import type { DocumentAssetsEventInternal } from '../EnrichedMarkdownNativeComponent';
import type { MarkdownDocumentAsset } from '../types/media';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps';

/** Revisions follow native parser inputs; JavaScript never reparses Markdown. */
export function useDocumentAssets(
  documentKey: string,
  onDocumentAssets: EnrichedMarkdownTextProps['onDocumentAssets'],
  resolveImageSource?: EnrichedMarkdownTextProps['resolveImageSource']
) {
  const document = useRef({ key: documentKey, revision: 1 });
  const reported = useRef(-1);
  if (document.current.key !== documentKey) {
    document.current = {
      key: documentKey,
      revision: document.current.revision + 1,
    };
  }
  const [manifest, setManifest] = useState<DocumentAssetsEventInternal>();
  const currentRevision = document.current.revision;
  const accepted =
    manifest?.revision === currentRevision ? manifest : undefined;
  const imageSources = useImageSources(
    resolveImageSource,
    currentRevision,
    accepted?.revision ?? -1,
    (accepted?.assets.filter((asset) => asset.kind === 'image') ??
      []) as NativeImageAsset[]
  );
  return {
    ...imageSources,
    documentRevision: document.current.revision,
    enableDocumentAssets: !!onDocumentAssets || !!resolveImageSource,
    onDocumentAssets: (
      event: NativeSyntheticEvent<DocumentAssetsEventInternal>
    ) => {
      const { revision, assets } = event.nativeEvent;
      if (
        revision !== document.current.revision ||
        reported.current === revision
      )
        return;
      setManifest(event.nativeEvent);
      reported.current = revision;
      onDocumentAssets?.({
        revision,
        assets: assets.map(
          ({ anchor: _anchor, ...asset }) => asset as MarkdownDocumentAsset
        ),
      });
    },
  };
}

import { useRef } from 'react';
import type { NativeSyntheticEvent } from 'react-native';
import type { DocumentAssetsEventInternal } from '../EnrichedMarkdownNativeComponent';
import type { MarkdownDocumentAsset } from '../types/media';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps';

/** Revisions follow native parser inputs; JavaScript never reparses Markdown. */
export function useDocumentAssets(
  documentKey: string,
  onDocumentAssets: EnrichedMarkdownTextProps['onDocumentAssets']
) {
  const document = useRef({ key: documentKey, revision: 1 });
  const reported = useRef(-1);
  if (document.current.key !== documentKey) {
    document.current = {
      key: documentKey,
      revision: document.current.revision + 1,
    };
  }
  return {
    documentRevision: document.current.revision,
    enableDocumentAssets: !!onDocumentAssets,
    onDocumentAssets: (
      event: NativeSyntheticEvent<DocumentAssetsEventInternal>
    ) => {
      const { revision, assets } = event.nativeEvent;
      if (
        revision !== document.current.revision ||
        reported.current === revision
      )
        return;
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

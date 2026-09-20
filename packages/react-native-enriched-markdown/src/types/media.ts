/** Placement in the native parsed document. */
export type MarkdownAssetPlacement =
  | 'block'
  | 'inline'
  | 'list'
  | 'table'
  | 'blockquote';

interface MarkdownAssetDescriptor {
  /** Occurrence ID, scoped to the component and document lineage. */
  id: string;
  url: string;
  altText: string;
  title: string;
  placement: MarkdownAssetPlacement;
}

export interface MarkdownMediaAsset extends MarkdownAssetDescriptor {
  kind: 'image' | 'video';
  /** Whether this occurrence is a standalone native media block. */
  eligible: boolean;
}

export interface MarkdownLinkAsset extends MarkdownAssetDescriptor {
  kind: 'link';
  eligible: false;
}

export type MarkdownDocumentAsset = MarkdownMediaAsset | MarkdownLinkAsset;

export interface MarkdownImageSource {
  uri: string;
  headers?: Record<string, string>;
}

export interface DocumentAssetsEvent {
  revision: number;
  assets: MarkdownDocumentAsset[];
}

import type { ImageSourceInternal } from './EnrichedMarkdownNativeComponent';
import type { EnrichedMarkdownTextProps } from './types/MarkdownTextProps';
import type { MarkdownMediaAsset } from './types/media';

export type NativeImageAsset = MarkdownMediaAsset & { anchor: string };
type Resolver = NonNullable<EnrichedMarkdownTextProps['resolveImageSource']>;
type Entry = {
  asset: NativeImageAsset;
  identity: string;
  status: 'queued' | 'active' | 'done';
  source?: ImageSourceInternal;
};

const identity = (asset: NativeImageAsset) => JSON.stringify(asset);
const stripAnchor = ({ anchor: _anchor, ...asset }: NativeImageAsset) => asset;

/** Per-occurrence decisions; superseded promises still count against the bound. */
export class ImageSourceState {
  private resolver?: Resolver;
  private lineage = -1;
  private entries = new Map<string, Entry>();
  private active = 0;
  private running = false;
  private changed?: () => void;

  configure(
    resolver: Resolver | undefined,
    lineage: number,
    assets: NativeImageAsset[]
  ) {
    if (resolver !== this.resolver || lineage !== this.lineage) {
      this.entries.clear();
      this.resolver = resolver;
      this.lineage = lineage;
    }
    const next = new Map<string, Entry>();
    if (resolver) {
      for (const asset of assets) {
        const key = identity(asset);
        const previous = this.entries.get(asset.id);
        next.set(
          asset.id,
          previous?.identity === key
            ? previous
            : { asset, identity: key, status: 'queued' }
        );
      }
    }
    this.entries = next;
  }

  sources(): ImageSourceInternal[] {
    return [...this.entries.values()].flatMap((entry) =>
      entry.source ? [entry.source] : []
    );
  }

  start(changed: () => void) {
    this.running = true;
    this.changed = changed;
    this.pump();
  }

  stop() {
    this.running = false;
    this.changed = undefined;
    this.entries.clear();
  }

  private pump() {
    if (!this.running || !this.resolver) return;
    for (const entry of this.entries.values()) {
      if (this.active >= 4) break;
      if (entry.status !== 'queued') continue;
      const resolve = this.resolver;
      entry.status = 'active';
      this.active++;
      // Always execute outside render. Synchronous throws follow rejection policy.
      Promise.resolve()
        .then(() => {
          if (this.entries.get(entry.asset.id) !== entry || !this.running)
            return undefined;
          return resolve(stripAnchor(entry.asset));
        })
        .then((result) => {
          if (this.entries.get(entry.asset.id) !== entry) return;
          if (
            result === null ||
            (result && typeof result.uri === 'string' && result.uri.length > 0)
          ) {
            entry.source = {
              id: entry.asset.id,
              url: entry.asset.url,
              anchor: entry.asset.anchor,
              uri: result?.uri ?? '',
              headers: Object.entries(result?.headers ?? {}).map(
                ([name, value]) => ({ name, value })
              ),
              useDefault: result === null,
            };
          }
        })
        .catch(() => {
          // A rejected source remains a placeholder until its identity changes.
        })
        .finally(() => {
          entry.status = 'done';
          this.active--;
          if (this.entries.get(entry.asset.id) === entry) this.changed?.();
          this.pump();
        });
    }
  }
}

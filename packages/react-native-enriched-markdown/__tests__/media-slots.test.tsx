import { View } from 'react-native';
import { act, useEffect, useState } from 'react';
import { createRoot } from 'test-renderer';
import type { ReactElement } from 'react';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type {
  MarkdownDocumentAsset,
  MarkdownMediaAsset,
} from '../src/types/media';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

const image = (id: string): MarkdownMediaAsset => ({
  id,
  kind: 'image',
  url: 'https://example.com/image.png',
  title: '',
  altText: 'An image',
  placement: 'block',
  eligible: true,
});

function setup(element: ReactElement) {
  const root = createRoot({
    textComponentTypes: ['EnrichedMarkdownNativeComponent'],
  });
  act(() => root.render(element));
  const native = () => {
    const instance = root.container.queryAll(
      (entry) => String(entry.type) === 'EnrichedMarkdownNativeComponent'
    )[0];
    if (!instance) throw new Error('Native markdown is missing');
    return instance;
  };
  const manifest = (
    revision: number,
    assets: (MarkdownDocumentAsset & { anchor?: string })[]
  ) => {
    act(() =>
      native().props.onDocumentAssets({
        nativeEvent: {
          revision,
          assets: assets.map((asset, index) => ({
            ...asset,
            anchor: asset.anchor ?? `0.${index}`,
          })),
        },
      })
    );
  };
  return { root, native, manifest };
}

it('uses native occurrence IDs, retaining null fallback and unsupported placements', () => {
  const onDocumentAssets = jest.fn();
  const renderMedia = jest.fn((asset) =>
    asset.id === 'asset-0' ? <View /> : null
  );
  const { native, manifest } = setup(
    <EnrichedMarkdownText
      markdown="![a](same)\n\n![b](same)"
      flavor="github"
      renderMedia={renderMedia}
      onDocumentAssets={onDocumentAssets}
    />
  );
  const revision = native().props.documentRevision;
  const assets = [
    image('asset-0'),
    image('asset-1'),
    {
      ...image('asset-2'),
      placement: 'list' as const,
      eligible: false,
    },
  ];
  manifest(revision, assets);
  expect(onDocumentAssets).toHaveBeenCalledWith({ revision, assets });
  expect(native().props.mediaOverrides).toMatchObject([
    { id: 'asset-0', height: 1, width: 0 },
  ]);
  expect(native().props.mediaOverridesRevision).toBe(revision);
  expect(renderMedia.mock.calls.every(([asset]) => asset.eligible)).toBe(true);
});

it('ignores stale manifests and deduplicates repeated reports of an accepted revision', () => {
  const onDocumentAssets = jest.fn();
  const { root, native, manifest } = setup(
    <EnrichedMarkdownText
      markdown="first"
      flavor="github"
      onDocumentAssets={onDocumentAssets}
    />
  );
  const first = native().props.documentRevision;
  manifest(first, [image('asset-0')]);
  manifest(first, [image('asset-0')]);
  expect(onDocumentAssets).toHaveBeenCalledTimes(1);
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="second"
        flavor="github"
        onDocumentAssets={onDocumentAssets}
      />
    )
  );
  const second = native().props.documentRevision;
  expect(second).toBeGreaterThan(first);
  manifest(first, [image('asset-0')]);
  expect(onDocumentAssets).toHaveBeenCalledTimes(1);
  expect(native().props.mediaOverridesRevision).toBe(-1);
  manifest(second, []);
  expect(onDocumentAssets).toHaveBeenLastCalledWith({
    revision: second,
    assets: [],
  });
});

it('restores native fallback when renderMedia changes to null and leaves link events active', () => {
  const onLinkPress = jest.fn();
  const { root, native, manifest } = setup(
    <EnrichedMarkdownText
      markdown="same"
      flavor="github"
      renderMedia={() => <View />}
      onLinkPress={onLinkPress}
    />
  );
  const revision = native().props.documentRevision;
  manifest(revision, [image('asset-0')]);
  expect(native().props.mediaOverrides).toHaveLength(1);
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="same"
        flavor="github"
        renderMedia={() => null}
        onLinkPress={onLinkPress}
      />
    )
  );
  expect(native().props.mediaOverridesRevision).toBe(revision);
  expect(native().props.mediaOverrides).toEqual([]);
  act(() =>
    native().props.onLinkPress({ nativeEvent: { url: 'https://example.com' } })
  );
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
});

it('feeds intrinsic React height back to native and rejects delayed old-width layouts', () => {
  const { root, native, manifest } = setup(
    <EnrichedMarkdownText
      markdown="![a](same)"
      flavor="github"
      renderMedia={() => <View />}
    />
  );
  const revision = native().props.documentRevision;
  manifest(revision, [image('asset-0')]);
  const emitFrame = (width: number) => {
    act(() =>
      native().props.onMediaLayout({
        nativeEvent: {
          revision,
          frames: [{ id: 'asset-0', x: 0, y: 20, width, height: 1 }],
        },
      })
    );
  };
  const slot = () => {
    const entry = root.container.queryAll(
      (instance) => instance.props.collapsable === false
    )[0];
    if (!entry) throw new Error('React slot missing');
    return entry;
  };
  emitFrame(300);
  const delayedLayout = slot().props.onLayout;
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { x: 0, y: 20, width: 300, height: 140 } },
    })
  );
  expect(native().props.mediaOverrides[0]).toMatchObject({
    width: 300,
    height: 140,
  });
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { x: 0, y: 20, width: 300, height: 210 } },
    })
  );
  expect(native().props.mediaOverrides[0]).toMatchObject({
    width: 300,
    height: 210,
  });
  emitFrame(220);
  expect(native().props.mediaOverrides[0]).toMatchObject({
    id: 'asset-0',
    width: 0,
    height: 1,
  });
  act(() =>
    delayedLayout({
      nativeEvent: { layout: { x: 0, y: 20, width: 300, height: 260 } },
    })
  );
  expect(native().props.mediaOverrides[0]).toMatchObject({
    id: 'asset-0',
    width: 0,
    height: 1,
  });
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { x: 0, y: 20, width: 220, height: 260 } },
    })
  );
  expect(native().props.mediaOverrides[0]).toMatchObject({
    width: 220,
    height: 260,
  });
});

it('keeps a stateful media renderer mounted across append and accepted manifest', () => {
  const mounts = jest.fn();
  const unmounts = jest.fn();
  function StatefulMedia() {
    const [count, setCount] = useState(0);
    useEffect(() => {
      mounts();
      return () => {
        unmounts();
      };
    }, []);
    return (
      <View
        testID="stateful-media"
        accessibilityLabel={String(count)}
        onTouchEnd={() => setCount((value) => value + 1)}
      />
    );
  }
  const renderMedia = () => <StatefulMedia />;
  const element = (markdown: string) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      renderMedia={renderMedia}
    />
  );
  const { root, native, manifest } = setup(element('![a](same)\n\n'));
  const first = native().props.documentRevision;
  const asset = image('asset-0');
  const frame = (revision: number) =>
    act(() =>
      native().props.onMediaLayout({
        nativeEvent: {
          revision,
          frames: [{ id: asset.id, x: 0, y: 0, width: 300, height: 140 }],
        },
      })
    );
  const player = () => {
    const entry = root.container.queryAll(
      (instance) => instance.props.testID === 'stateful-media'
    )[0];
    if (!entry) throw new Error('Stateful media missing');
    return entry;
  };
  const slot = () =>
    root.container.queryAll(
      (instance) => instance.props.collapsable === false
    )[0]!;
  manifest(first, [asset]);
  frame(first);
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { width: 300, height: 140 } },
    })
  );
  const staleLayout = slot().props.onLayout;
  act(() => player().props.onTouchEnd());
  expect(player().props.accessibilityLabel).toBe('1');
  act(() => root.render(element('![a](same)\n\nappended text')));
  const second = native().props.documentRevision;
  expect(second).toBeGreaterThan(first);
  expect(player().props.accessibilityLabel).toBe('1');
  expect(mounts).toHaveBeenCalledTimes(1);
  expect(unmounts).not.toHaveBeenCalled();
  expect(native().props.mediaOverridesRevision).toBe(first);
  expect(native().props.mediaOverrides[0]).toMatchObject({
    id: asset.id,
    url: asset.url,
    kind: 'image',
    anchor: '0.0',
    width: 300,
    height: 140,
  });
  act(() =>
    staleLayout({ nativeEvent: { layout: { width: 300, height: 999 } } })
  );
  expect(native().props.mediaOverrides[0].height).toBe(140);
  frame(second);
  expect(player().props.accessibilityLabel).toBe('1');
  expect(mounts).toHaveBeenCalledTimes(1);
  manifest(second, [asset]);
  expect(player().props.accessibilityLabel).toBe('1');
  expect(native().props.mediaOverridesRevision).toBe(second);
  expect(native().props.mediaOverrides[0].height).toBe(140);
  frame(second);
  expect(player().props.accessibilityLabel).toBe('1');
  expect(mounts).toHaveBeenCalledTimes(1);
  expect(unmounts).not.toHaveBeenCalled();
});

it('does not carry slots on arbitrary edits or parser-option changes', () => {
  const renderMedia = () => <View testID="media" />;
  const element = (markdown: string, underline = false) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      md4cFlags={{ underline }}
      renderMedia={renderMedia}
    />
  );
  const { root, native, manifest } = setup(element('![a](same)\n\n'));
  const accept = () => {
    const revision = native().props.documentRevision;
    manifest(revision, [image('asset-0')]);
    act(() =>
      native().props.onMediaLayout({
        nativeEvent: {
          revision,
          frames: [{ id: 'asset-0', x: 0, y: 0, width: 300, height: 140 }],
        },
      })
    );
  };
  accept();
  act(() => root.render(element('arbitrary replacement')));
  expect(
    root.container.queryAll((entry) => entry.props.testID === 'media')
  ).toHaveLength(0);
  expect(native().props.mediaOverridesRevision).toBe(-1);
  accept();
  act(() => root.render(element('arbitrary replacement appended', true)));
  expect(
    root.container.queryAll((entry) => entry.props.testID === 'media')
  ).toHaveLength(0);
  expect(native().props.mediaOverridesRevision).toBe(-1);
});

it('reconciles reference reclassification, identical URLs, and ineligible occurrences', () => {
  const unmounts = jest.fn();
  function Media() {
    useEffect(
      () => () => {
        unmounts();
      },
      []
    );
    return <View testID="media" />;
  }
  const renderMedia = () => <Media />;
  const element = (markdown: string) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      renderMedia={renderMedia}
    />
  );
  const { root, native, manifest } = setup(
    element('![earlier][ref]\n\n![later](same)\n\n')
  );
  const first = native().props.documentRevision;
  manifest(first, [{ ...image('asset-0'), anchor: '0.1' }]);
  act(() =>
    native().props.onMediaLayout({
      nativeEvent: {
        revision: first,
        frames: [{ id: 'asset-0', x: 0, y: 0, width: 300, height: 140 }],
      },
    })
  );
  act(() =>
    root.render(element('![earlier][ref]\n\n![later](same)\n\n[ref]: same'))
  );
  expect(unmounts).not.toHaveBeenCalled();
  const revision = native().props.documentRevision;
  // Same ordinal, URL and kind now refer to the newly resolved earlier image.
  manifest(revision, [
    { ...image('asset-0'), anchor: '0.0' },
    { ...image('asset-1'), anchor: '0.1' },
  ]);
  expect(unmounts).toHaveBeenCalledTimes(1);
  expect(
    native().props.mediaOverrides.every(
      (entry: { height: number }) => entry.height === 1
    )
  ).toBe(true);
  act(() =>
    native().props.onMediaLayout({
      nativeEvent: {
        revision,
        frames: [{ id: 'asset-0', x: 0, y: 0, width: 300, height: 1 }],
      },
    })
  );
  manifest(revision, [
    {
      ...image('asset-0'),
      eligible: false,
      placement: 'inline',
      anchor: '0.0',
    },
  ]);
  expect(
    root.container.queryAll((entry) => entry.props.testID === 'media')
  ).toHaveLength(0);
});

it('rejects an old-width measurement during an append before its manifest arrives', () => {
  const renderMedia = () => <View />;
  const element = (markdown: string) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      renderMedia={renderMedia}
    />
  );
  const { root, native, manifest } = setup(element('![a](same)\n\n'));
  const first = native().props.documentRevision;
  manifest(first, [image('asset-0')]);
  act(() =>
    native().props.onMediaLayout({
      nativeEvent: {
        revision: first,
        frames: [{ id: 'asset-0', x: 0, y: 0, width: 300, height: 140 }],
      },
    })
  );
  const slot = () =>
    root.container.queryAll((entry) => entry.props.collapsable === false)[0]!;
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { width: 300, height: 140 } },
    })
  );
  act(() => root.render(element('![a](same)\n\nappend')));
  const second = native().props.documentRevision;
  act(() =>
    native().props.onMediaLayout({
      nativeEvent: {
        revision: second,
        frames: [{ id: 'asset-0', x: 0, y: 0, width: 220, height: 140 }],
      },
    })
  );
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { width: 300, height: 999 } },
    })
  );
  expect(native().props.mediaOverrides[0].height).toBe(140);
  manifest(second, [image('asset-0')]);
  expect(native().props.mediaOverrides[0]).toMatchObject({
    width: 0,
    height: 1,
  });
  act(() =>
    slot().props.onLayout({
      nativeEvent: { layout: { width: 220, height: 180 } },
    })
  );
  expect(native().props.mediaOverrides[0]).toMatchObject({
    width: 220,
    height: 180,
  });
});

import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

it('reports accepted occurrences directly, strips private anchors, and rejects stale/duplicate events', () => {
  const callback = jest.fn();
  const root = createRoot({
    textComponentTypes: ['EnrichedMarkdownNativeComponent'],
  });
  const render = (markdown: string, md4cFlags = {}) =>
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown={markdown}
          flavor="github"
          onDocumentAssets={callback}
          md4cFlags={md4cFlags}
        />
      )
    );
  const native = () =>
    root.container.queryAll(
      (entry) => String(entry.type) === 'EnrichedMarkdownNativeComponent'
    )[0]!;
  render('![first](same) [link](destination) ![second](same)');
  const first = native().props.documentRevision;
  const assets = [
    {
      id: 'asset-0',
      kind: 'image',
      url: 'same',
      altText: 'first',
      title: '',
      placement: 'inline',
      eligible: false,
    },
    {
      id: 'asset-1',
      kind: 'link',
      url: 'destination',
      altText: 'link',
      title: '',
      placement: 'inline',
      eligible: false,
    },
    {
      id: 'asset-2',
      kind: 'image',
      url: 'same',
      altText: 'second',
      title: '',
      placement: 'inline',
      eligible: false,
    },
  ];
  const emit = (revision: number, entries = assets) =>
    act(() =>
      native().props.onDocumentAssets({
        nativeEvent: {
          revision,
          assets: entries.map((asset, index) => ({
            ...asset,
            anchor: `0.${index}`,
          })),
        },
      })
    );
  emit(first);
  emit(first);
  expect(callback).toHaveBeenCalledTimes(1);
  expect(callback).toHaveBeenLastCalledWith({ revision: first, assets });
  render('');
  const empty = native().props.documentRevision;
  expect(empty).toBeGreaterThan(first);
  emit(first);
  expect(callback).toHaveBeenCalledTimes(1);
  emit(empty, []);
  expect(callback).toHaveBeenLastCalledWith({ revision: empty, assets: [] });
  render('', { underline: true });
  expect(native().props.documentRevision).toBeGreaterThan(empty);
});

it('keeps the manifest opt-in and leaves CommonMark rendering unchanged', () => {
  const root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  act(() =>
    root.render(<EnrichedMarkdownText markdown="![a](same)" flavor="github" />)
  );
  expect(
    root.container.queryAll(
      (entry) => String(entry.type) === 'EnrichedMarkdownNativeComponent'
    )[0]!.props.enableDocumentAssets
  ).toBe(false);
  const callback = jest.fn();
  act(() =>
    root.render(
      <EnrichedMarkdownText markdown="![a](same)" onDocumentAssets={callback} />
    )
  );
  expect(
    root.container.queryAll(
      (entry) => String(entry.type) === 'EnrichedMarkdownTextNativeComponent'
    )
  ).toHaveLength(1);
  expect(callback).not.toHaveBeenCalled();
});

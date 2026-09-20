import { act } from 'react';
import { createRoot } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type { EnrichedMarkdownTextProps } from '../src/types/MarkdownTextProps';
import type { MarkdownImageSource } from '../src/types/media';

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));
jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

const fixture = {
  id: 'asset-1',
  kind: 'image',
  url: './image.png',
  title: 'original',
  altText: 'image',
  placement: 'table',
  eligible: false,
  anchor: '0.0.1',
};
const pixel =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';
const setup = () => {
  const root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
    ],
  });
  const native = () =>
    root.container.queryAll((entry) =>
      String(entry.type).startsWith('EnrichedMarkdown')
    )[0]!;
  const render = (props: Partial<EnrichedMarkdownTextProps> = {}) =>
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown="[![image](./image.png)](https://example.com)"
          flavor="github"
          {...props}
        />
      )
    );
  const emit = async (revision = native().props.documentRevision) => {
    await act(async () => {
      native().props.onDocumentAssets({
        nativeEvent: {
          revision,
          assets: [
            {
              ...fixture,
              id: 'asset-0',
              kind: 'link',
              url: 'https://example.com',
            },
            fixture,
          ],
        },
      });
    });
  };
  return { root, native, render, emit };
};

it('resolves accepted native image descriptors while preserving semantic image/link callbacks and manifests', async () => {
  const { root, native, render, emit } = setup();
  const resolveImageSource = jest.fn(async () => ({
    uri: pixel,
    headers: { Accept: 'image/png' },
  }));
  const onDocumentAssets = jest.fn();
  const onImagePress = jest.fn();
  const onLinkPress = jest.fn();
  render({ resolveImageSource, onDocumentAssets, onImagePress, onLinkPress });
  expect(resolveImageSource).not.toHaveBeenCalled();
  expect(native().props.imageSources).toEqual([]);
  await emit();
  const { anchor, ...descriptor } = fixture;
  expect(anchor).toBeDefined();
  expect(resolveImageSource).toHaveBeenCalledTimes(1);
  expect(resolveImageSource).toHaveBeenCalledWith(descriptor);
  expect(native().props.imageSources).toEqual([
    {
      id: fixture.id,
      url: fixture.url,
      anchor: fixture.anchor,
      uri: pixel,
      headers: [{ name: 'Accept', value: 'image/png' }],
      useDefault: false,
    },
  ]);
  expect(onDocumentAssets.mock.calls[0]![0].assets[1]).toEqual(descriptor);
  act(() => {
    native().props.onImagePress({
      nativeEvent: { url: fixture.url, altText: fixture.altText },
    });
    native().props.onLinkPress({ nativeEvent: { url: 'https://example.com' } });
  });
  expect(onImagePress).toHaveBeenCalledWith({
    url: fixture.url,
    altText: fixture.altText,
  });
  expect(onLinkPress).toHaveBeenCalledWith({ url: 'https://example.com' });
  render({
    resolveImageSource,
    onDocumentAssets,
    containerStyle: { width: 200 },
    markdownStyle: { paragraph: { fontSize: 20 } },
  });
  await emit();
  expect(resolveImageSource).toHaveBeenCalledTimes(1);
  act(() => root.unmount());
});

it('supports late opt-in, ignores replacement-document promises, and keeps CommonMark/default behavior off', async () => {
  const { root, native, render, emit } = setup();
  render();
  const initial = native().props.documentRevision;
  expect(native().props.enableImageSourceResolution).toBe(false);
  expect(native().props.enableDocumentAssets).toBe(false);
  let finish!: (source: MarkdownImageSource) => void;
  const pending = new Promise<MarkdownImageSource>((done) => {
    finish = done;
  });
  const resolveImageSource = jest.fn(() => pending);
  render({ resolveImageSource });
  expect(native().props.documentRevision).toBeGreaterThan(initial);
  await emit(initial);
  expect(resolveImageSource).not.toHaveBeenCalled();
  await emit();
  expect(resolveImageSource).toHaveBeenCalledTimes(1);
  render({ markdown: 'replacement', resolveImageSource });
  await act(async () => {
    finish({ uri: pixel });
  });
  expect(native().props.imageSources).toEqual([]);
  render({ resolveImageSource, flavor: 'commonmark' });
  expect(native().type).toBe('EnrichedMarkdownTextNativeComponent');
  expect(native().props.resolveImageSource).toBeUndefined();
  expect(resolveImageSource).toHaveBeenCalledTimes(1);
  act(() => root.unmount());
});

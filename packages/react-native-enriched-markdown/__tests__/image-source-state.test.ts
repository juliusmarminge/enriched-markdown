import { ImageSourceState } from '../src/imageSourceState';
import type { NativeImageAsset } from '../src/imageSourceState';
import type {
  MarkdownImageSource,
  MarkdownMediaAsset,
} from '../src/types/media';

const asset = (id = 'asset-0', anchor = '0.0'): NativeImageAsset => ({
  id,
  anchor,
  kind: 'image',
  url: './same.png',
  title: 'original title',
  altText: 'original alt',
  eligible: false,
  placement: 'table',
});
const flush = async () => {
  for (let i = 0; i < 12; i++) await Promise.resolve();
};
const deferred = () => {
  let resolve!: (value: MarkdownImageSource | null) => void;
  const promise = new Promise<MarkdownImageSource | null>((done) => {
    resolve = done;
  });
  return { promise, resolve };
};

it('holds pending sources, strips private anchors, and distinguishes null from transport', async () => {
  const pending = deferred();
  const resolver = jest.fn(() => pending.promise);
  const state = new ImageSourceState();
  state.configure(resolver, 1, [asset()]);
  expect(resolver).not.toHaveBeenCalled();
  state.start(jest.fn());
  await flush();
  expect(resolver).toHaveBeenCalledWith({
    id: 'asset-0',
    kind: 'image',
    url: './same.png',
    title: 'original title',
    altText: 'original alt',
    eligible: false,
    placement: 'table',
  });
  expect(state.sources()).toEqual([]);
  pending.resolve(null);
  await flush();
  expect(state.sources()).toEqual([
    {
      id: 'asset-0',
      url: './same.png',
      anchor: '0.0',
      uri: '',
      headers: [],
      useDefault: true,
    },
  ]);
});

it('bounds callbacks at four including superseded active promises, dedupes repeated manifests', async () => {
  const tasks = Array.from({ length: 8 }, deferred);
  const resolver = jest.fn(
    (value: MarkdownMediaAsset) => tasks[Number(value.id.slice(6))]!.promise
  );
  const state = new ImageSourceState();
  const images = tasks.map((_, i) => asset(`asset-${i}`, `0.${i}`));
  state.configure(resolver, 1, images);
  state.start(jest.fn());
  await flush();
  expect(resolver).toHaveBeenCalledTimes(4);
  state.configure(resolver, 1, images);
  state.start(jest.fn());
  await flush();
  expect(resolver).toHaveBeenCalledTimes(4);
  state.configure(resolver, 2, images.slice(4));
  state.start(jest.fn());
  await flush();
  expect(resolver).toHaveBeenCalledTimes(4);
  tasks[0]!.resolve({ uri: 'stale' });
  await flush();
  expect(resolver).toHaveBeenCalledTimes(5);
  expect(state.sources()).toEqual([]);
  for (const task of tasks) task.resolve(null);
  await flush();
});

it('resolves identical URLs independently and retains decisions and active work across safe append', async () => {
  const first = deferred();
  const resolver = jest.fn((value) =>
    value.id === 'asset-0'
      ? first.promise
      : { uri: 'signed-second', headers: { Authorization: 'second' } }
  );
  const state = new ImageSourceState();
  state.configure(resolver, 1, [asset()]);
  state.start(jest.fn());
  await flush();
  state.configure(resolver, 1, [asset(), asset('asset-1', '0.1')]);
  state.start(jest.fn());
  first.resolve({ uri: 'signed-first' });
  await flush();
  expect(state.sources().map((source) => source.uri)).toEqual([
    'signed-first',
    'signed-second',
  ]);
  state.configure(resolver, 1, [asset(), asset('asset-1', '0.1')]);
  state.start(jest.fn());
  await flush();
  expect(resolver).toHaveBeenCalledTimes(2);
});

it('ignores stale anchor/revision/resolver completions and unmounted completions', async () => {
  for (const change of ['anchor', 'lineage', 'resolver', 'unmount']) {
    const old = deferred();
    const resolver = jest
      .fn(() => new Promise<MarkdownImageSource | null>(() => {}))
      .mockImplementationOnce(() => old.promise);
    const state = new ImageSourceState();
    const changed = jest.fn();
    state.configure(resolver, 1, [asset()]);
    state.start(changed);
    await flush();
    if (change === 'unmount') state.stop();
    else
      state.configure(
        change === 'resolver' ? () => null : resolver,
        change === 'lineage' ? 2 : 1,
        [asset('asset-0', change === 'anchor' ? '0.1' : '0.0')]
      );
    old.resolve({ uri: 'stale-secret' });
    await flush();
    expect(
      state.sources().some((source) => source.uri === 'stale-secret')
    ).toBe(false);
  }
});

it('keeps rejections/throws as placeholders and does not retry on layout-only renders', async () => {
  for (const resolver of [
    jest.fn(() => Promise.reject(new Error('failed'))),
    jest.fn(() => {
      throw new Error('failed');
    }),
  ]) {
    const state = new ImageSourceState();
    state.configure(resolver, 1, [asset()]);
    state.start(jest.fn());
    await flush();
    state.configure(resolver, 1, [asset()]);
    state.start(jest.fn());
    await flush();
    expect(state.sources()).toEqual([]);
    expect(resolver).toHaveBeenCalledTimes(1);
  }
});

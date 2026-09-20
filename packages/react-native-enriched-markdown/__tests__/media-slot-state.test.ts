import {
  acceptMediaMeasurement,
  mediaOverrideForFrame,
  validMediaFrames,
} from '../src/mediaSlotState';

const frame = { id: 'asset-0', x: 0, y: 12, width: 300, height: 1 };

it('rejects old revisions, invalid dimensions, and old-width layouts', () => {
  const next = { id: frame.id, width: 300, height: 150 };
  expect(acceptMediaMeasurement(1, 2, frame, next, undefined)).toBe(false);
  expect(
    acceptMediaMeasurement(2, 2, frame, { ...next, width: 200 }, undefined)
  ).toBe(false);
  expect(
    acceptMediaMeasurement(2, 2, frame, { ...next, height: NaN }, undefined)
  ).toBe(false);
  expect(
    acceptMediaMeasurement(2, 2, frame, { ...next, height: -1 }, undefined)
  ).toBe(false);
});

it('accepts dynamic height and zero height, suppressing subpixel feedback', () => {
  const previous = { id: frame.id, width: 300, height: 150 };
  expect(
    acceptMediaMeasurement(
      2,
      2,
      frame,
      { ...previous, height: 150.1 },
      previous
    )
  ).toBe(false);
  expect(
    acceptMediaMeasurement(2, 2, frame, { ...previous, height: 190 }, previous)
  ).toBe(true);
  expect(
    acceptMediaMeasurement(2, 2, frame, { ...previous, height: 0 }, previous)
  ).toBe(true);
});

it('invalidates measured heights when native width changes', () => {
  const measurement = { id: frame.id, width: 300, height: 150 };
  expect(mediaOverrideForFrame(frame.id, frame, measurement)).toEqual(
    measurement
  );
  expect(
    mediaOverrideForFrame(frame.id, { ...frame, width: 220 }, measurement)
  ).toEqual({ id: frame.id, width: 0, height: 1 });
});

it('keeps duplicate URLs independent through occurrence IDs', () => {
  const measurements = {
    'asset-0': { id: 'asset-0', width: 300, height: 150 },
    'asset-1': { id: 'asset-1', width: 300, height: 250 },
  };
  expect(
    mediaOverrideForFrame('asset-0', frame, measurements['asset-0']).height
  ).toBe(150);
  expect(
    mediaOverrideForFrame(
      'asset-1',
      { ...frame, id: 'asset-1' },
      measurements['asset-1']
    ).height
  ).toBe(250);
});

it('rejects unusable native frames without losing valid zero-height slots', () => {
  expect(
    validMediaFrames([
      frame,
      { ...frame, width: 0 },
      { ...frame, x: Infinity },
      { ...frame, height: -2 },
      { ...frame, id: 'asset-2', height: 0 },
    ])
  ).toEqual([frame, { ...frame, id: 'asset-2', height: 0 }]);
});

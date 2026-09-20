import type { MediaFrameInternal } from './EnrichedMarkdownNativeComponent';

export interface MediaMeasurement {
  id: string;
  width: number;
  height: number;
}

export const sameMediaSize = (a: number, b: number) => Math.abs(a - b) < 0.5;

/** Accept only finite native frames with usable widths. */
export const validMediaFrames = (
  frames: readonly MediaFrameInternal[]
): MediaFrameInternal[] =>
  frames.filter(
    ({ x, y, width, height }) =>
      [x, y, width, height].every(Number.isFinite) && width > 0 && height >= 0
  );

/** A width change requires React to measure again before native uses the height. */
export const mediaOverrideForFrame = (
  id: string,
  frame: MediaFrameInternal | undefined,
  measurement: MediaMeasurement | undefined
): MediaMeasurement =>
  frame && measurement && sameMediaSize(frame.width, measurement.width)
    ? measurement
    : { id, width: 0, height: 1 };

/** Reject stale onLayout callbacks and suppress subpixel feedback loops. */
export const acceptMediaMeasurement = (
  eventRevision: number,
  revision: number,
  frame: MediaFrameInternal | undefined,
  next: MediaMeasurement,
  previous: MediaMeasurement | undefined
): boolean =>
  eventRevision === revision &&
  !!frame &&
  Number.isFinite(next.width) &&
  Number.isFinite(next.height) &&
  next.width > 0 &&
  next.height >= 0 &&
  sameMediaSize(frame.width, next.width) &&
  (!previous ||
    !sameMediaSize(previous.width, next.width) ||
    !sameMediaSize(previous.height, next.height));

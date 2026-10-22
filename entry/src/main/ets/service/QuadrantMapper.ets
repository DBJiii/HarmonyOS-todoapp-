/**
 * Pure geometry / colour mapping for the quadrant plane.
 *
 * All functions are deterministic and side-effect free. Coordinates are in vp,
 * matching ArkUI component coordinates and Canvas draw units.
 *
 * World model: urgency is the horizontal axis (0 left -> 100 right) and
 * significance is the vertical axis (0 bottom -> 100 top). The plane origin
 * (divider == 50 / 50) sits at the centre of the canvas, shifted by pan.
 */
import { Constants } from '../common/Constants';
import { Quadrant } from '../model/Todo';

/** Snapshot of the plane's viewport transform. */
export interface PlaneTransform {
  width: number;
  height: number;
  zoom: number;
  panX: number;
  panY: number;
}

/** A point in vp screen coordinates. */
export interface ScreenPoint {
  x: number;
  y: number;
}

/** A pair of value-domain coordinates (or deltas). */
export interface ValuePoint {
  urgency: number;
  significance: number;
}

export function clampZoom(zoom: number): number {
  if (zoom < Constants.ZOOM_MIN) {
    return Constants.ZOOM_MIN;
  }
  if (zoom > Constants.ZOOM_MAX) {
    return Constants.ZOOM_MAX;
  }
  return zoom;
}

/**
 * Quadrant of a (urgency, significance) point.
 * Boundary rule: a value exactly equal to the divider belongs to the >= side,
 * so (50, 50) resolves to Q1.
 */
export function quadrantOf(urgency: number, significance: number): Quadrant {
  const urgent: boolean = urgency >= Constants.DIVIDER;
  const significant: boolean = significance >= Constants.DIVIDER;
  if (urgent && significant) {
    return Quadrant.Q1;
  }
  if (!urgent && significant) {
    return Quadrant.Q2;
  }
  if (!urgent && !significant) {
    return Quadrant.Q3;
  }
  return Quadrant.Q4;
}

export function colorFor(quadrant: Quadrant): string {
  if (quadrant === Quadrant.Q1) {
    return Constants.COLOR_Q1;
  }
  if (quadrant === Quadrant.Q2) {
    return Constants.COLOR_Q2;
  }
  if (quadrant === Quadrant.Q3) {
    return Constants.COLOR_Q3;
  }
  return Constants.COLOR_Q4;
}

export function colorForValues(urgency: number, significance: number): string {
  return colorFor(quadrantOf(urgency, significance));
}

/** vp distance covered by one value unit at the given zoom. */
export function vpPerUnit(zoom: number): number {
  return Constants.BASE_VP_PER_UNIT * zoom;
}

/** Maps a value-domain point to a vp screen point. */
export function valueToPoint(urgency: number, significance: number, plane: PlaneTransform): ScreenPoint {
  const cx: number = plane.width / 2;
  const cy: number = plane.height / 2;
  const unit: number = vpPerUnit(plane.zoom);
  const x: number = cx + plane.panX + (urgency - Constants.DIVIDER) * unit;
  const y: number = cy + plane.panY - (significance - Constants.DIVIDER) * unit;
  return { x: x, y: y };
}

/** Inverse of {@link valueToPoint}; the value domain is unbounded. */
export function pointToValue(x: number, y: number, plane: PlaneTransform): ValuePoint {
  const cx: number = plane.width / 2;
  const cy: number = plane.height / 2;
  const unit: number = vpPerUnit(plane.zoom);
  const urgency: number = Constants.DIVIDER + (x - cx - plane.panX) / unit;
  const significance: number = Constants.DIVIDER - (y - cy - plane.panY) / unit;
  return { urgency: urgency, significance: significance };
}

/** Converts a vp drag delta into a value-domain delta at the given zoom. */
export function screenDeltaToValueDelta(deltaX: number, deltaY: number, zoom: number): ValuePoint {
  const unit: number = vpPerUnit(zoom);
  return { urgency: deltaX / unit, significance: -deltaY / unit };
}

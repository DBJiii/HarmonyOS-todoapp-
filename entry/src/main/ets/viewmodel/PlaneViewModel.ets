/**
 * Plane view state: zoom / pan transform and the currently activated bar.
 * Non-persistent - resets on app restart.
 */
import { Constants } from '../common/Constants';
import { clampZoom, PlaneTransform } from '../service/QuadrantMapper';

@ObservedV2
export class PlaneViewModel {
  @Trace zoom: number = Constants.ZOOM_DEFAULT;
  @Trace panX: number = 0;
  @Trace panY: number = 0;
  /** Empty string means "no active bar". */
  @Trace activeTodoId: string = '';
  @Trace planeWidth: number = 0;
  @Trace planeHeight: number = 0;

  private pinchBaseZoom: number = Constants.ZOOM_DEFAULT;
  private pinchBasePanX: number = 0;
  private pinchBasePanY: number = 0;
  private pinchFocalX: number = 0;
  private pinchFocalY: number = 0;

  /** Records the viewport size reported by the plane component. */
  setViewport(width: number, height: number): void {
    if (width > 0) {
      this.planeWidth = width;
    }
    if (height > 0) {
      this.planeHeight = height;
    }
  }

  /** Snapshot the zoom / pan / focal point at pinch start. */
  beginPinch(focalX: number, focalY: number): void {
    this.pinchBaseZoom = this.zoom;
    this.pinchBasePanX = this.panX;
    this.pinchBasePanY = this.panY;
    this.pinchFocalX = focalX;
    this.pinchFocalY = focalY;
  }

  /**
   * Applies a cumulative pinch scale, keeping the world point under the pinch
   * focal point anchored to the same screen position.
   */
  applyPinch(scale: number): void {
    if (scale <= 0 || this.pinchBaseZoom <= 0) {
      return;
    }
    const next: number = clampZoom(this.pinchBaseZoom * scale);
    const ratio: number = next / this.pinchBaseZoom;
    const cx: number = this.planeWidth / 2;
    const cy: number = this.planeHeight / 2;
    this.panX = this.pinchFocalX - cx - (this.pinchFocalX - cx - this.pinchBasePanX) * ratio;
    this.panY = this.pinchFocalY - cy - (this.pinchFocalY - cy - this.pinchBasePanY) * ratio;
    this.zoom = next;
  }

  /** Stepwise zoom for the on-screen buttons; anchors the canvas centre. */
  zoomBy(factor: number): void {
    const next: number = clampZoom(this.zoom * factor);
    if (next === this.zoom) {
      return;
    }
    const ratio: number = next / this.zoom;
    this.panX = this.panX * ratio;
    this.panY = this.panY * ratio;
    this.zoom = next;
  }

  applyPan(deltaX: number, deltaY: number): void {
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    this.panX = this.panX + deltaX;
    this.panY = this.panY + deltaY;
  }

  setActive(id: string): void {
    this.activeTodoId = id;
  }

  clearActive(): void {
    this.activeTodoId = '';
  }

  isActive(id: string): boolean {
    return this.activeTodoId.length > 0 && this.activeTodoId === id;
  }

  resetTransform(): void {
    this.zoom = Constants.ZOOM_DEFAULT;
    this.panX = 0;
    this.panY = 0;
  }

  /** Current transform snapshot consumed by the mapper and the canvas. */
  get transform(): PlaneTransform {
    const snapshot: PlaneTransform = {
      width: this.planeWidth,
      height: this.planeHeight,
      zoom: this.zoom,
      panX: this.panX,
      panY: this.panY
    };
    return snapshot;
  }
}

export const planeViewModel: PlaneViewModel = new PlaneViewModel();

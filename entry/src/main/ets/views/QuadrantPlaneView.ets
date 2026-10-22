/**
 * The quadrant plane: a Canvas that draws the grid, axes and quadrant tint,
 * with pinch-to-zoom and drag-to-pan gestures on the empty canvas.
 *
 * The Canvas is the bottom layer of MainPage's Stack; todo bars are rendered
 * above it, so gestures that start on a bar never reach the plane.
 */
import { Constants } from '../common/Constants';
import { PlaneViewModel } from '../viewmodel/PlaneViewModel';

@ComponentV2
export struct QuadrantPlaneView {
  @Param planeVm: PlaneViewModel = new PlaneViewModel();
  /** Fired when the user taps empty canvas (deactivate the active bar). */
  @Event onEmptyTap: () => void = () => {};

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private lastWidth: number = -1;
  private lastHeight: number = -1;
  private lastZoom: number = -1;
  private lastDrawPanX: number = 0;
  private lastDrawPanY: number = 0;

  /** Redraw whenever the shared transform changes (e.g. zoom buttons). */
  @Monitor('planeVm.zoom', 'planeVm.panX', 'planeVm.panY')
  onTransformChange(): void {
    this.draw();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.planeVm.setViewport(Number(newValue.width), Number(newValue.height));
        this.draw();
      })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart((event: GestureEvent) => {
              this.planeVm.beginPinch(event.pinchCenterX, event.pinchCenterY);
            })
            .onActionUpdate((event: GestureEvent) => {
              this.planeVm.applyPinch(event.scale);
              this.draw();
            }),
          PanGesture({ fingers: 1, distance: 4 })
            .onActionStart(() => {
              this.lastPanX = 0;
              this.lastPanY = 0;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.planeVm.applyPan(event.offsetX - this.lastPanX, event.offsetY - this.lastPanY);
              this.lastPanX = event.offsetX;
              this.lastPanY = event.offsetY;
              console.log(`[DEBUG][H3] location=views/QuadrantPlaneView.ets | message=pan gesture update | data=offsetX=${event.offsetX},offsetY=${event.offsetY},panX=${this.planeVm.panX},panY=${this.planeVm.panY} | ts=${Date.now()} | runId=post-fix`);
              this.draw();
            })
            .onActionEnd(() => {
              this.lastPanX = 0;
              this.lastPanY = 0;
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              this.onEmptyTap();
            })
        )
      )
  }

  private draw(): void {
    if (!this.ready) {
      return;
    }
    const vm: PlaneViewModel = this.planeVm;
    const width: number = vm.planeWidth;
    const height: number = vm.planeHeight;
    if (width <= 0 || height <= 0) {
      return;
    }
    // Skip redundant redraws when the transform has not actually changed.
    if (width === this.lastWidth && height === this.lastHeight && vm.zoom === this.lastZoom &&
      vm.panX === this.lastDrawPanX && vm.panY === this.lastDrawPanY) {
      console.log(`[DEBUG][H2] location=views/QuadrantPlaneView.ets | message=draw skipped as redundant | data=panX=${vm.panX},panY=${vm.panY},zoom=${vm.zoom} | ts=${Date.now()} | runId=post-fix`);
      return;
    }
    this.lastWidth = width;
    this.lastHeight = height;
    this.lastZoom = vm.zoom;
    this.lastDrawPanX = vm.panX;
    this.lastDrawPanY = vm.panY;
    console.log(`[DEBUG][H4] location=views/QuadrantPlaneView.ets | message=plane viewport size | data=width=${width},height=${height} | ts=${Date.now()} | runId=post-fix`);
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, width, height);

    ctx.fillStyle = '#F6F6FB';
    ctx.fillRect(0, 0, width, height);

    const originX: number = width / 2 + vm.panX;
    const originY: number = height / 2 + vm.panY;
    console.log(`[DEBUG][H1] location=views/QuadrantPlaneView.ets | message=axis origins | data=originX=${originX},originY=${originY},zoom=${vm.zoom} | ts=${Date.now()} | runId=post-fix`);

    // Quadrant tint.
    ctx.globalAlpha = 0.14;
    ctx.fillStyle = Constants.COLOR_Q2;
    ctx.fillRect(0, 0, originX, originY);
    ctx.fillStyle = Constants.COLOR_Q1;
    ctx.fillRect(originX, 0, width - originX, originY);
    ctx.fillStyle = Constants.COLOR_Q3;
    ctx.fillRect(0, originY, originX, height - originY);
    ctx.fillStyle = Constants.COLOR_Q4;
    ctx.fillRect(originX, originY, width - originX, height - originY);
    ctx.globalAlpha = 1.0;

    // Grid: an unbounded lattice covering the whole visible viewport, so panning
    // and zooming never run out of grid regardless of the value range.
    const unit: number = Constants.BASE_VP_PER_UNIT * vm.zoom;
    const step: number = Constants.GRID_STEP;
    ctx.strokeStyle = '#D9D9E4';
    ctx.lineWidth = 1;
    if (unit > 0) {
      const leftValue: number = Constants.DIVIDER + (0 - originX) / unit;
      const rightValue: number = Constants.DIVIDER + (width - originX) / unit;
      const startX: number = Math.floor(leftValue / step) * step;
      for (let v = startX; v <= rightValue; v += step) {
        const gx: number = originX + (v - Constants.DIVIDER) * unit;
        ctx.beginPath();
        ctx.moveTo(gx, 0);
        ctx.lineTo(gx, height);
        ctx.stroke();
      }
      const topValue: number = Constants.DIVIDER - (0 - originY) / unit;
      const bottomValue: number = Constants.DIVIDER - (height - originY) / unit;
      const startY: number = Math.floor(bottomValue / step) * step;
      for (let v = startY; v <= topValue; v += step) {
        const gy: number = originY - (v - Constants.DIVIDER) * unit;
        ctx.beginPath();
        ctx.moveTo(0, gy);
        ctx.lineTo(width, gy);
        ctx.stroke();
      }
    }

    // Axes at the 50 / 50 divider.
    ctx.strokeStyle = '#8C8CA6';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(originX, 0);
    ctx.lineTo(originX, height);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, originY);
    ctx.lineTo(width, originY);
    ctx.stroke();

    // Axis labels.
    ctx.fillStyle = '#5C5C74';
    ctx.font = '12vp sans-serif';
    ctx.fillText('Urgency >', width - 88, originY - 10);
    ctx.fillText('Significance ^', originX + 8, 22);

    // Quadrant labels sit next to the origin, one per quadrant, and move with
    // the axis (no edge clamping, so they all track the origin consistently).
    ctx.font = '14vp sans-serif';
    ctx.fillStyle = '#9A9AB0';
    ctx.fillText('Q2', originX - 34, originY - 14);
    ctx.fillText('Q1', originX + 12, originY - 14);
    ctx.fillText('Q3', originX - 34, originY + 26);
    ctx.fillText('Q4', originX + 12, originY + 26);
  }
}

/**
 * A single todo bar rendered above the plane canvas.
 *
 * The bar's screen position is derived from its urgency / significance via
 * {@link QuadrantMapper}, and its background colour encodes the quadrant with
 * an eased transition when it changes.
 *
 * Interaction:
 *  - long-press  -> activate (shows Edit / Delete) and allow dragging
 *  - drag        -> live reposition; on drop urgency / significance are written
 *  - double-tap  -> toggle completion
 *  - single-tap  -> expand / collapse the optional description
 */
import { Constants } from '../common/Constants';
import { Todo } from '../model/Todo';
import { colorForValues, valueToPoint, ScreenPoint } from '../service/QuadrantMapper';
import { PlaneViewModel } from '../viewmodel/PlaneViewModel';
import { TodoViewModel } from '../viewmodel/TodoViewModel';

@ComponentV2
export struct TodoBarView {
  @Param todo: Todo = new Todo();
  @Param planeVm: PlaneViewModel = new PlaneViewModel();
  @Param todoVm: TodoViewModel = new TodoViewModel();

  @Event onEdit: () => void = () => {};
  @Event onDelete: () => void = () => {};

  @Local dragOffsetX: number = 0;
  @Local dragOffsetY: number = 0;
  @Local dragging: boolean = false;

  private get isActive(): boolean {
    return this.planeVm.isActive(this.todo.id);
  }

  private get expanded(): boolean {
    return this.todoVm.isExpanded(this.todo.id);
  }

  private get barColor(): string {
    return colorForValues(this.todo.urgency, this.todo.significance);
  }

  private get screenX(): number {
    const point: ScreenPoint = valueToPoint(this.todo.urgency, this.todo.significance, this.planeVm.transform);
    return point.x - Constants.BAR_WIDTH / 2 + this.dragOffsetX;
  }

  private get screenY(): number {
    const point: ScreenPoint = valueToPoint(this.todo.urgency, this.todo.significance, this.planeVm.transform);
    return point.y - Constants.BAR_HEIGHT / 2 + this.dragOffsetY;
  }

  private get overdue(): boolean {
    return this.todo.isOverdue(Date.now());
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private formatDeadline(): string {
    const date = new Date(this.todo.deadline);
    const day: string =
      `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())}`;
    const time: string = `${this.pad2(date.getHours())}:${this.pad2(date.getMinutes())}`;
    return `${day} ${time}`;
  }

  private onLongPress(): void {
    this.planeVm.setActive(this.todo.id);
  }

  private onDragFinish(): void {
    if (this.dragging) {
      this.todoVm.moveBy(this.todo.id, this.dragOffsetX, this.dragOffsetY, this.planeVm.zoom);
    }
    this.dragging = false;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
  }

  build() {
    Column() {
      Row() {
        Text(this.todo.title)
          .fontSize(13)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .decoration({
            type: this.todo.completed ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: Color.White
          })
          .layoutWeight(1)

        if (this.todo.hasDescription()) {
          Row()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor('#CCFFFFFF')
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .height(Constants.BAR_HEIGHT)
      .padding({ left: 10, right: 10 })
      .backgroundColor(this.barColor)
      .animation({ duration: Constants.COLOR_ANIM_DURATION, curve: Curve.EaseInOut })
      .borderRadius(8)
      .borderWidth(this.isActive ? 2 : 0)
      .borderColor('#FFFFFF')
      .opacity(this.todo.completed ? 0.45 : 1)
      .shadow({ radius: 4, color: '#33000000', offsetX: 0, offsetY: 2 })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          GestureGroup(GestureMode.Sequence,
            LongPressGesture({ repeat: false, duration: 350 })
              .onAction(() => {
                this.onLongPress();
              }),
            PanGesture({ fingers: 1, distance: 3 })
              .onActionStart(() => {
                this.dragging = !this.todo.completed;
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.dragging) {
                  this.dragOffsetX = event.offsetX;
                  this.dragOffsetY = event.offsetY;
                }
              })
              .onActionEnd(() => {
                this.onDragFinish();
              })
          ),
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction(() => {
                this.todoVm.setCompleted(this.todo.id, !this.todo.completed);
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                this.todoVm.toggleExpanded(this.todo.id);
              })
          )
        )
      )

      if (this.isActive) {
        Row({ space: 8 }) {
          Button('Edit')
            .fontSize(12)
            .height(30)
            .backgroundColor('#3D3D52')
            .onClick(() => {
              this.onEdit();
            })
          Button('Delete')
            .fontSize(12)
            .height(30)
            .backgroundColor('#C62828')
            .onClick(() => {
              this.onDelete();
            })
        }
        .margin({ top: 6 })
      }

      if (this.expanded && this.todo.hasDescription()) {
        Text(this.todo.description)
          .fontSize(12)
          .fontColor('#2B2B3C')
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding(8)
          .width('100%')
          .backgroundColor('#F2F2F8')
          .borderRadius(6)
          .margin({ top: 6 })
      }
      if (this.todo.hasDeadline()) {
        Row({ space: 4 }) {
          Text(this.overdue ? 'Overdue' : 'Due')
            .fontSize(10)
            .fontColor(this.overdue ? '#C62828' : '#6B6B80')
            .fontWeight(this.overdue ? FontWeight.Bold : FontWeight.Normal)
          Text(this.formatDeadline())
            .fontSize(10)
            .fontColor(this.overdue ? '#C62828' : '#6B6B80')
            .fontWeight(this.overdue ? FontWeight.Bold : FontWeight.Normal)
        }
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .margin({ top: 6 })
      }
    }
    .width(Constants.BAR_WIDTH)
    .position({ x: this.screenX, y: this.screenY })
  }
}

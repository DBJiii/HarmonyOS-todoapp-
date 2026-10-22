/**
 * Main page: hosts the quadrant plane, overlays every todo bar and provides
 * the entry points for Create and Settings.
 */
import { Todo } from '../model/Todo';
import { TodoViewModel, todoViewModel } from '../viewmodel/TodoViewModel';
import { PlaneViewModel, planeViewModel } from '../viewmodel/PlaneViewModel';
import { QuadrantPlaneView } from '../views/QuadrantPlaneView';
import { TodoBarView } from '../views/TodoBarView';
import { ReminderService } from '../service/ReminderService';
import { DeadlineWatcher } from '../service/DeadlineWatcher';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants, EDIT_MODE_CREATE, EDIT_MODE_EDIT, EditParams } from '../common/Constants';

const DOMAIN: number = 0x0000;
const TAG: string = 'MainPage';

@Entry
@Preview
@ComponentV2
struct MainPage {
  private todoVm: TodoViewModel = todoViewModel;
  private planeVm: PlaneViewModel = planeViewModel;

  aboutToAppear(): void {
    this.todoVm.load();
    this.planeVm.clearActive();
    // Ask for notification authorisation up-front; degrades gracefully.
    ReminderService.ensurePermission();
    // Re-register background reminders for todos persisted from a prior run.
    this.todoVm.rescheduleReminders();
    // In-app safety net: alert when a deadline is reached while running.
    DeadlineWatcher.start(
      () => this.todoVm.todos,
      (todo: Todo) => {
        ReminderService.notifyDeadline(todo);
        this.showDeadlineAlert(todo);
      }
    );
  }

  aboutToDisappear(): void {
    DeadlineWatcher.stop();
  }

  private showDeadlineAlert(todo: Todo): void {
    try {
      this.getUIContext().showAlertDialog({
        title: 'Deadline reached',
        message: `"${todo.title}" is due now.`,
        primaryButton: {
          value: 'Mark done',
          action: () => {
            this.todoVm.setCompleted(todo.id, true);
          }
        },
        secondaryButton: {
          value: 'Dismiss',
          action: () => {
          }
        }
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'show deadline dialog failed: %{public}s', JSON.stringify(error));
    }
  }

  onPageShow(): void {
    // Returning from Create / Edit / Settings: re-read the persisted list.
    this.todoVm.load();
  }

  private openCreate(): void {
    const params: EditParams = { mode: EDIT_MODE_CREATE, todoId: '' };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TodoEditPage', params: params });
  }

  private openSettings(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
  }

  private openEdit(todoId: string): void {
    this.planeVm.setActive(todoId);
    const params: EditParams = { mode: EDIT_MODE_EDIT, todoId: todoId };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TodoEditPage', params: params });
  }

  private confirmDelete(todo: Todo): void {
    this.getUIContext().showAlertDialog({
      title: 'Delete todo',
      message: `Delete "${todo.title}" permanently?`,
      primaryButton: {
        value: 'Delete',
        action: () => {
          this.todoVm.delete(todo.id);
          if (this.planeVm.isActive(todo.id)) {
            this.planeVm.clearActive();
          }
        }
      },
      secondaryButton: {
        value: 'Cancel',
        action: () => {
        }
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      QuadrantPlaneView({
        planeVm: this.planeVm,
        onEmptyTap: () => {
          this.planeVm.clearActive();
        }
      })

      ForEach(this.todoVm.todos, (todo: Todo) => {
        TodoBarView({
          todo: todo,
          planeVm: this.planeVm,
          todoVm: this.todoVm,
          onEdit: () => {
            this.openEdit(todo.id);
          },
          onDelete: () => {
            this.confirmDelete(todo);
          }
        })
      }, (todo: Todo) => todo.id)

      Column() {
        Row() {

          Blank()
          Button('Settings')
            .fontSize(14)
            .backgroundColor('#EDEDF4')
            .fontColor('#2B2B3C')
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Row({ space: 8 }) {
          Button('-')
            .fontSize(20)
            .width(48)
            .height(40)
            .backgroundColor('#EDEDF4')
            .fontColor('#2B2B3C')
            .onClick(() => {
              this.planeVm.zoomBy(1 / Constants.ZOOM_STEP);
            })
          Button('+')
            .fontSize(20)
            .width(48)
            .height(40)
            .backgroundColor('#EDEDF4')
            .fontColor('#2B2B3C')
            .onClick(() => {
              this.planeVm.zoomBy(Constants.ZOOM_STEP);
            })
          Blank()
          Button('+ New Todo')
            .fontSize(15)
            .backgroundColor('#2B2B3C')
            .onClick(() => {
              this.openCreate();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }
}

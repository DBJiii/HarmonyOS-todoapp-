/**
 * Shared Create / Edit page.
 *
 * The mode is driven by router params: `create` starts from defaults (sliders
 * centred at 50/50) while `edit` is pre-filled from the existing todo.
 */
import { Constants, EDIT_MODE_CREATE, EDIT_MODE_EDIT, EditParams } from '../common/Constants';
import { Todo, TodoDraft } from '../model/Todo';
import { TodoViewModel, todoViewModel } from '../viewmodel/TodoViewModel';

@Entry
@ComponentV2
struct TodoEditPage {
  @Local isEditMode: boolean = false;
  @Local editingId: string = '';
  @Local title: string = '';
  @Local description: string = '';
  @Local hasDeadline: boolean = false;
  @Local deadlineDate: Date = new Date(Date.now() + 86400000);
  @Local deadlineHour: number = 9;
  @Local deadlineMinute: number = 0;
  @Local errorText: string = '';

  private todoVm: TodoViewModel = todoViewModel;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as EditParams;
    const mode: string = params?.mode ?? EDIT_MODE_CREATE;
    const todoId: string = params?.todoId ?? '';
    this.isEditMode = mode === EDIT_MODE_EDIT;
    this.editingId = todoId;
    if (this.isEditMode && todoId.length > 0) {
      const todo: Todo | undefined = this.todoVm.find(todoId);
      if (todo !== undefined) {
        this.title = todo.title;
        this.description = todo.description;
        this.hasDeadline = todo.hasDeadline();
        if (todo.hasDeadline()) {
          const date = new Date(todo.deadline);
          this.deadlineDate = date;
          this.deadlineHour = date.getHours();
          this.deadlineMinute = date.getMinutes();
        }
      }
    }
  }

  private computeDeadline(): number {
    if (!this.hasDeadline) {
      return 0;
    }
    const date = new Date(this.deadlineDate.getFullYear(), this.deadlineDate.getMonth(),
      this.deadlineDate.getDate(), this.deadlineHour, this.deadlineMinute, 0, 0);
    return date.getTime();
  }

  private onSave(): void {
    const trimmed: string = this.title.trim();
    if (trimmed.length === 0) {
      this.errorText = 'A title is required.';
      return;
    }
    const draft = new TodoDraft();
    draft.title = trimmed;
    draft.description = this.description;
    draft.deadline = this.computeDeadline();
    if (this.isEditMode && this.editingId.length > 0) {
      const existing: Todo | undefined = this.todoVm.find(this.editingId);
      // Urgency / significance are set by dragging on the plane, not here.
      draft.urgency = existing !== undefined ? existing.urgency : Constants.DEFAULT_VALUE;
      draft.significance = existing !== undefined ? existing.significance : Constants.DEFAULT_VALUE;
      this.todoVm.update(this.editingId, draft);
    } else {
      draft.urgency = Constants.DEFAULT_VALUE;
      draft.significance = Constants.DEFAULT_VALUE;
      this.todoVm.create(draft);
    }
    this.getUIContext().getRouter().back();
  }

  private onCancel(): void {
    this.getUIContext().getRouter().back();
  }

  build() {
    Column() {
      Row() {
        Text(this.isEditMode ? 'Edit Todo' : 'New Todo')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2B2B3C')
        Blank()
        Button('Cancel')
          .fontSize(14)
          .backgroundColor('#EDEDF4')
          .fontColor('#2B2B3C')
          .onClick(() => {
            this.onCancel();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 6 }) {
            Text('Title *').fontSize(14).fontColor('#2B2B3C')
            TextInput({ placeholder: 'What needs doing?', text: this.title })
              .onChange((value: string) => {
                this.title = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Text('Description (optional)').fontSize(14).fontColor('#2B2B3C')
            TextArea({ placeholder: 'Add any details...', text: this.description })
              .height(96)
              .onChange((value: string) => {
                this.description = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Text('Urgency (X) and significance (Y) are set by dragging the bar on the plane. ' +
            'The axes crossing is 0; left/down is negative, right/up is positive.')
            .fontSize(12)
            .fontColor('#6B6B80')
            .width('100%')

          Row() {
            Text('Deadline').fontSize(14).fontColor('#2B2B3C')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.hasDeadline })
              .onChange((isOn: boolean) => {
                this.hasDeadline = isOn;
              })
          }
          .width('100%')

          if (this.hasDeadline) {
            DatePicker({
              start: new Date(2000, 0, 1),
              end: new Date(2100, 11, 31),
              selected: this.deadlineDate
            })
              .onDateChange((value: Date) => {
                this.deadlineDate = value;
              })

            TimePicker({ selected: this.deadlineDate })
              .useMilitaryTime(true)
              .onChange((value: TimePickerResult) => {
                this.deadlineHour = value.hour;
                this.deadlineMinute = value.minute;
              })
          }

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor('#E53935')
          }

          Button(this.isEditMode ? 'Save changes' : 'Create todo')
            .width('100%')
            .backgroundColor('#2B2B3C')
            .onClick(() => {
              this.onSave();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

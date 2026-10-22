/**
 * Settings page: Notifications & Reminders plus About / App info.
 */
import { Constants } from '../common/Constants';
import { SettingsViewModel, settingsViewModel } from '../viewmodel/SettingsViewModel';

const APP_VERSION: string = '1.0.0';

@Entry
@ComponentV2
struct SettingsPage {
  private settingsVm: SettingsViewModel = settingsViewModel;
  @Local leadIndex: number = 0;

  aboutToAppear(): void {
    this.settingsVm.load();
    this.leadIndex = this.indexOfLead(this.settingsVm.advanceLeadMinutes);
  }

  private indexOfLead(minutes: number): number {
    for (let i = 0; i < Constants.ADVANCE_LEAD_OPTIONS.length; i++) {
      if (Constants.ADVANCE_LEAD_OPTIONS[i] === minutes) {
        return i;
      }
    }
    return Constants.ADVANCE_LEAD_OPTIONS.length - 1;
  }

  private leadLabel(minutes: number): string {
    if (minutes < 60) {
      return `${minutes} minutes`;
    }
    if (minutes < 1440) {
      return `${Math.floor(minutes / 60)} hour(s)`;
    }
    return `${Math.floor(minutes / 1440)} day(s)`;
  }

  private leadOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let i = 0; i < Constants.ADVANCE_LEAD_OPTIONS.length; i++) {
      const option: SelectOption = { value: this.leadLabel(Constants.ADVANCE_LEAD_OPTIONS[i]) };
      options.push(option);
    }
    return options;
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(14).fontColor('#2B2B3C')
      Blank()
      Text(value).fontSize(14).fontColor('#6B6B80')
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Column() {
      Row() {
        Text('Settings')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2B2B3C')
        Blank()
        Button('Back')
          .fontSize(14)
          .backgroundColor('#EDEDF4')
          .fontColor('#2B2B3C')
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column({ space: 18 }) {
          Text('Notifications & Reminders')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2B2B3C')
            .width('100%')

          Row() {
            Column({ space: 2 }) {
              Text('Enable reminders').fontSize(14).fontColor('#2B2B3C')
              Text('Notify at the deadline and in advance')
                .fontSize(12)
                .fontColor('#6B6B80')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.settingsVm.remindersEnabled })
              .onChange((isOn: boolean) => {
                this.settingsVm.setRemindersEnabled(isOn);
              })
          }
          .width('100%')

          Row() {
            Column({ space: 2 }) {
              Text('Advance lead time').fontSize(14).fontColor('#2B2B3C')
              Text('How early the advance reminder fires')
                .fontSize(12)
                .fontColor('#6B6B80')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Select(this.leadOptions())
              .selected(this.leadIndex)
              .value(this.leadLabel(this.settingsVm.advanceLeadMinutes))
              .font({ size: 14 })
              .onSelect((index: number, value?: string) => {
                this.leadIndex = index;
                this.settingsVm.setAdvanceLeadMinutes(Constants.ADVANCE_LEAD_OPTIONS[index]);
              })
          }
          .width('100%')

          if (!this.settingsVm.remindersEnabled) {
            Text('Reminders are off. Deadlines still show on each bar.')
              .fontSize(12)
              .fontColor('#FB8C00')
              .width('100%')
          }

          Divider()

          Text('About')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2B2B3C')
            .width('100%')

          this.infoRow('App name', 'Quadrant Todo')
          this.infoRow('Version', APP_VERSION)
          this.infoRow('Storage', 'Local device only')
          this.infoRow('Reminders', 'Background agent + notifications')

          Text('A single-user, offline todo app that maps urgency (X) and significance (Y) ' +
            'onto an Eisenhower quadrant plane. Drag a bar to re-prioritise; its colour follows the quadrant.')
            .fontSize(12)
            .fontColor('#6B6B80')
            .width('100%')
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

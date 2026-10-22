/**
 * Settings state (Notifications & Reminders) with persistence and reminder
 * rescheduling on change.
 */
import { Constants } from '../common/Constants';
import { AppSettings, Todo } from '../model/Todo';
import { TodoRepository } from '../data/TodoRepository';
import { ReminderService } from '../service/ReminderService';

@ObservedV2
export class SettingsViewModel {
  @Trace remindersEnabled: boolean = Constants.DEFAULT_REMINDERS_ENABLED;
  @Trace advanceLeadMinutes: number = Constants.DEFAULT_ADVANCE_LEAD_MINUTES;

  load(): void {
    const settings: AppSettings = TodoRepository.loadSettings();
    this.remindersEnabled = settings.remindersEnabled;
    this.advanceLeadMinutes = settings.advanceLeadMinutes;
  }

  setRemindersEnabled(enabled: boolean): void {
    if (this.remindersEnabled === enabled) {
      return;
    }
    this.remindersEnabled = enabled;
    this.persist();
  }

  setAdvanceLeadMinutes(minutes: number): void {
    if (minutes <= 0 || this.advanceLeadMinutes === minutes) {
      return;
    }
    this.advanceLeadMinutes = minutes;
    this.persist();
  }

  /** Human readable label for the current lead time. */
  advanceLeadLabel(): string {
    const minutes: number = this.advanceLeadMinutes;
    if (minutes < 60) {
      return `${minutes} minutes before`;
    }
    if (minutes < 1440) {
      return `${Math.floor(minutes / 60)} hour(s) before`;
    }
    return `${Math.floor(minutes / 1440)} day(s) before`;
  }

  private persist(): void {
    const settings = new AppSettings();
    settings.remindersEnabled = this.remindersEnabled;
    settings.advanceLeadMinutes = this.advanceLeadMinutes;
    TodoRepository.saveSettings(settings);
    const todos: Todo[] = TodoRepository.loadTodos();
    ReminderService.rescheduleAll(todos, settings);
  }
}

export const settingsViewModel: SettingsViewModel = new SettingsViewModel();

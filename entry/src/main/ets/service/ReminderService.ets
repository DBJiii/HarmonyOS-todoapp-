/**
 * Deadline reminders built on the background Reminder Agent plus the
 * Notification manager used for the runtime authorisation prompt.
 *
 * Agent reminders may be blocked by device policy; every call is guarded and
 * degrades gracefully (logging only) so the rest of the app keeps working.
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, Want, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { AppSettings, Todo } from '../model/Todo';

const DOMAIN: number = 0x0000;
const TAG: string = 'ReminderService';
/** Error code returned by requestEnableNotification when the user refuses. */
const ERR_NOTIFICATION_REFUSED: number = 1600004;

export class ReminderService {
  private static abilityContext: common.UIAbilityContext | undefined = undefined;
  private static reminderIds: Map<string, number[]> = new Map<string, number[]>();
  private static nextNotificationId: number = Constants.REMINDER_NOTIFICATION_ID_BASE;

  static init(context: common.UIAbilityContext): void {
    ReminderService.abilityContext = context;
  }

  /** Requests notification authorisation; returns whether notifications are on. */
  static async requestPermission(): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        return true;
      }
      const ctx: common.UIAbilityContext | undefined = ReminderService.abilityContext;
      if (ctx === undefined) {
        return false;
      }
      await notificationManager.requestEnableNotification(ctx);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      if (err.code === ERR_NOTIFICATION_REFUSED) {
        hilog.warn(DOMAIN, TAG, 'notification permission refused');
      } else {
        hilog.error(DOMAIN, TAG, 'notification permission failed: %{public}s', JSON.stringify(err));
      }
      return false;
    }
  }

  /** Fire-and-forget permission request used when entering the app. */
  static ensurePermission(): void {
    ReminderService.requestPermission().then((granted: boolean) => {
      hilog.info(DOMAIN, TAG, 'notification permission granted: %{public}s', `${granted}`);
    });
  }

  /** Deterministic per-todo notification id so repeat posts replace, not pile up. */
  private static notificationIdFor(todoId: string): number {
    let hash: number = 0;
    for (let i = 0; i < todoId.length; i++) {
      hash = (hash * 31 + todoId.charCodeAt(i)) % 100000;
    }
    return Constants.REMINDER_NOTIFICATION_ID_BASE + hash;
  }

  /**
   * Posts an immediate system notification for a todo whose deadline has just
   * been reached. Tapping the notification launches the app. Used by the
   * in-app watcher as a fallback when the background Reminder Agent cannot
   * deliver. Degrades gracefully to logging only.
   */
  static notifyDeadline(todo: Todo): void {
    const notificationId: number = ReminderService.notificationIdFor(todo.id);
    const want: Want = {
      bundleName: Constants.BUNDLE_NAME,
      abilityName: Constants.ABILITY_NAME
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: notificationId,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(info).then((agent: WantAgent) => {
      const request: notificationManager.NotificationRequest = {
        id: notificationId,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        wantAgent: agent,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'Deadline reached',
            text: todo.title,
            additionalText: 'Tap to open the app.'
          }
        }
      };
      notificationManager.publish(request).then(() => {
        hilog.info(DOMAIN, TAG, 'deadline notification published: %{public}s', todo.id);
      }).catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'deadline notification failed: %{public}s', JSON.stringify(error));
      });
    }).catch((error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'wantAgent creation failed: %{public}s', JSON.stringify(error));
    });
  }

  private static toLocalDateTime(time: number): reminderAgentManager.LocalDateTime {
    const date = new Date(time);
    const dt: reminderAgentManager.LocalDateTime = {
      year: date.getFullYear(),
      month: date.getMonth() + 1,
      day: date.getDate(),
      hour: date.getHours(),
      minute: date.getMinutes(),
      second: date.getSeconds()
    };
    return dt;
  }

  private static buildCalendar(todo: Todo, triggerTime: number, isAdvance: boolean,
    notificationId: number): reminderAgentManager.ReminderRequestCalendar {
    const title: string = isAdvance ? `Upcoming: ${todo.title}` : `Due now: ${todo.title}`;
    const content: string = isAdvance ? 'This todo deadline is approaching.' : 'This todo is due now.';
    const reminder: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: ReminderService.toLocalDateTime(triggerTime),
      title: title,
      content: content,
      expiredContent: content,
      notificationId: notificationId,
      wantAgent: {
        pkgName: Constants.BUNDLE_NAME,
        abilityName: Constants.ABILITY_NAME
      }
    };
    return reminder;
  }

  private static publish(todoId: string, reminder: reminderAgentManager.ReminderRequestCalendar): void {
    reminderAgentManager.publishReminder(reminder).then((reminderId: number) => {
      const existing: number[] = ReminderService.reminderIds.get(todoId) ?? [];
      existing.push(reminderId);
      ReminderService.reminderIds.set(todoId, existing);
      hilog.info(DOMAIN, TAG, 'reminder published: %{public}s', `${reminderId}`);
    }).catch((error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'agent reminder unavailable, degrading: %{public}s', JSON.stringify(error));
    });
  }

  /** Schedules at-deadline and advance reminders for one todo. */
  static scheduleFor(todo: Todo, settings: AppSettings): void {
    ReminderService.cancelFor(todo.id);
    if (!settings.remindersEnabled || !todo.hasDeadline() || todo.completed) {
      return;
    }
    const now: number = Date.now();
    const advanceTime: number = todo.deadline - settings.advanceLeadMinutes * Constants.MILLIS_PER_MINUTE;
    if (advanceTime > now) {
      ReminderService.nextNotificationId = ReminderService.nextNotificationId + 1;
      ReminderService.publish(todo.id,
        ReminderService.buildCalendar(todo, advanceTime, true, ReminderService.nextNotificationId));
    }
    if (todo.deadline > now) {
      ReminderService.nextNotificationId = ReminderService.nextNotificationId + 1;
      ReminderService.publish(todo.id,
        ReminderService.buildCalendar(todo, todo.deadline, false, ReminderService.nextNotificationId));
    }
  }

  /** Cancels every reminder previously scheduled for a todo. */
  static cancelFor(todoId: string): void {
    const ids: number[] | undefined = ReminderService.reminderIds.get(todoId);
    if (ids === undefined) {
      return;
    }
    for (let i = 0; i < ids.length; i++) {
      reminderAgentManager.cancelReminder(ids[i]).catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'cancel reminder failed: %{public}s', JSON.stringify(error));
      });
    }
    ReminderService.reminderIds.delete(todoId);
  }

  /** Rebuilds every reminder; used after settings or todo changes. */
  static rescheduleAll(todos: Todo[], settings: AppSettings): void {
    reminderAgentManager.cancelAllReminders().then(() => {
      ReminderService.reminderIds.clear();
      ReminderService.scheduleAll(todos, settings);
    }).catch((error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'cancel all reminders failed: %{public}s', JSON.stringify(error));
      ReminderService.reminderIds.clear();
      ReminderService.scheduleAll(todos, settings);
    });
  }

  private static scheduleAll(todos: Todo[], settings: AppSettings): void {
    for (let i = 0; i < todos.length; i++) {
      ReminderService.scheduleFor(todos[i], settings);
    }
  }
}

/**
 * In-app deadline watcher.
 *
 * The background Reminder Agent (see {@link ReminderService}) delivers system
 * notifications for deadlines, including while the app is closed, but it can be
 * unavailable (blocked by device policy / emulator). This watcher polls the
 * in-memory todo list while the app is running and fires a callback exactly
 * once per todo when its deadline passes, so the user always gets an in-app
 * reminder.
 *
 * Only deadlines reached after {@link start} are reported, so relaunching the
 * app does not re-alert for long-overdue todos.
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Todo } from '../model/Todo';

const DOMAIN: number = 0x0000;
const TAG: string = 'DeadlineWatcher';
/** How often the todo list is scanned for newly reached deadlines (ms). */
const POLL_INTERVAL_MS: number = 15000;

export class DeadlineWatcher {
  private static timerId: number = -1;
  /** Deadlines at or before this timestamp have already been considered. */
  private static lastCheckMs: number = 0;
  private static provider: (() => Todo[]) | undefined = undefined;
  private static listener: ((todo: Todo) => void) | undefined = undefined;

  /**
   * Starts polling. `provider` returns the current todo list and `listener` is
   * invoked once for each todo whose deadline passes while polling.
   */
  static start(provider: () => Todo[], listener: (todo: Todo) => void): void {
    DeadlineWatcher.provider = provider;
    DeadlineWatcher.listener = listener;
    DeadlineWatcher.lastCheckMs = Date.now();
    if (DeadlineWatcher.timerId < 0) {
      DeadlineWatcher.timerId = setInterval(() => {
        DeadlineWatcher.check();
      }, POLL_INTERVAL_MS);
    }
  }

  static stop(): void {
    if (DeadlineWatcher.timerId >= 0) {
      clearInterval(DeadlineWatcher.timerId);
      DeadlineWatcher.timerId = -1;
    }
    DeadlineWatcher.provider = undefined;
    DeadlineWatcher.listener = undefined;
    DeadlineWatcher.lastCheckMs = 0;
  }

  private static check(): void {
    const provider: (() => Todo[]) | undefined = DeadlineWatcher.provider;
    const listener: ((todo: Todo) => void) | undefined = DeadlineWatcher.listener;
    if (provider === undefined || listener === undefined) {
      return;
    }
    const now: number = Date.now();
    const since: number = DeadlineWatcher.lastCheckMs;
    DeadlineWatcher.lastCheckMs = now;
    const todos: Todo[] = provider();
    for (let i = 0; i < todos.length; i++) {
      const todo: Todo = todos[i];
      if (!todo.hasDeadline() || todo.completed) {
        continue;
      }
      if (todo.deadline > since && todo.deadline <= now) {
        hilog.info(DOMAIN, TAG, 'deadline reached: %{public}s', todo.id);
        listener(todo);
      }
    }
  }
}

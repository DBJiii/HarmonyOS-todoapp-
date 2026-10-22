/**
 * Observable todo list plus all CRUD / interaction operations.
 *
 * Owns the single source of truth for todos in memory, persists every change
 * through {@link TodoRepository} and keeps reminders in sync via
 * {@link ReminderService}.
 */
import { AppSettings, Todo, TodoDraft } from '../model/Todo';
import { TodoRepository } from '../data/TodoRepository';
import { ReminderService } from '../service/ReminderService';
import { screenDeltaToValueDelta, ValuePoint } from '../service/QuadrantMapper';

@ObservedV2
export class TodoViewModel {
  @Trace todos: Todo[] = [];
  @Trace expandedIds: string[] = [];

  /**
   * Loads the persisted list, RECONCILING into the existing Todo instances.
   *
   * Do NOT replace an array item with a new object that keeps the same `id`
   * (the ForEach key): ArkUI's ForEach then reuses the old child WITHOUT
   * rebinding it, so a bar keeps observing a detached instance and stops
   * updating (dragging/editing would no longer move or recolour the bar).
   * Reusing the existing instance and copying fields keeps every bar bound to
   * the object that actually lives in `todos`.
   */
  load(): void {
    const persisted: Todo[] = TodoRepository.loadTodos();
    const reconciled: Todo[] = [];
    const ids: string[] = [];
    for (let i = 0; i < persisted.length; i++) {
      const incoming: Todo = persisted[i];
      // `find` still searches the previous `this.todos` here (not yet replaced).
      const current: Todo | undefined = this.find(incoming.id);
      if (current !== undefined) {
        current.title = incoming.title;
        current.description = incoming.description;
        current.urgency = incoming.urgency;
        current.significance = incoming.significance;
        current.deadline = incoming.deadline;
        current.completed = incoming.completed;
        current.createdAt = incoming.createdAt;
        current.updatedAt = incoming.updatedAt;
        reconciled.push(current);
      } else {
        reconciled.push(incoming);
      }
      ids.push(incoming.id);
    }
    this.todos = reconciled;
    this.expandedIds = this.expandedIds.filter((id: string): boolean => ids.includes(id));
  }

  create(draft: TodoDraft): Todo {
    const todo: Todo = Todo.create(
      TodoRepository.newId(),
      draft.title.trim(),
      draft.description,
      draft.urgency,
      draft.significance,
      draft.deadline
    );
    this.todos = this.todos.concat([todo]);
    this.persist();
    this.scheduleAll();
    return todo;
  }

  update(id: string, draft: TodoDraft): void {
    const todo: Todo | undefined = this.find(id);
    if (todo === undefined) {
      return;
    }
    todo.title = draft.title.trim();
    todo.description = draft.description;
    todo.urgency = draft.urgency;
    todo.significance = draft.significance;
    todo.deadline = draft.deadline;
    todo.updatedAt = Date.now();
    this.persist();
    this.scheduleAll();
  }

  delete(id: string): void {
    this.todos = this.todos.filter((item: Todo): boolean => item.id !== id);
    this.expandedIds = this.expandedIds.filter((item: string): boolean => item !== id);
    this.persist();
    ReminderService.cancelFor(id);
    this.scheduleAll();
  }

  setCompleted(id: string, completed: boolean): void {
    const todo: Todo | undefined = this.find(id);
    if (todo === undefined) {
      return;
    }
    todo.completed = completed;
    todo.updatedAt = Date.now();
    this.persist();
    this.scheduleAll();
  }

  /** Writes back urgency / significance from a drop position. */
  moveBy(id: string, deltaX: number, deltaY: number, zoom: number): void {
    const todo: Todo | undefined = this.find(id);
    if (todo === undefined || todo.completed) {
      return;
    }
    const delta: ValuePoint = screenDeltaToValueDelta(deltaX, deltaY, zoom);
    todo.urgency = todo.urgency + delta.urgency;
    todo.significance = todo.significance + delta.significance;
    todo.updatedAt = Date.now();
    this.persist();
  }

  toggleExpanded(id: string): void {
    const todo: Todo | undefined = this.find(id);
    if (todo === undefined || !todo.hasDescription()) {
      return;
    }
    if (this.isExpanded(id)) {
      this.expandedIds = this.expandedIds.filter((item: string): boolean => item !== id);
    } else {
      this.expandedIds = this.expandedIds.concat([id]);
    }
  }

  isExpanded(id: string): boolean {
    return this.expandedIds.includes(id);
  }

  find(id: string): Todo | undefined {
    for (let i = 0; i < this.todos.length; i++) {
      if (this.todos[i].id === id) {
        return this.todos[i];
      }
    }
    return undefined;
  }

  count(): number {
    return this.todos.length;
  }

  /** Re-registers reminder-agent reminders (call once on app launch). */
  rescheduleReminders(): void {
    this.scheduleAll();
  }

  private persist(): void {
    TodoRepository.saveTodos(this.todos);
  }

  private scheduleAll(): void {
    const settings: AppSettings = TodoRepository.loadSettings();
    ReminderService.rescheduleAll(this.todos, settings);
  }
}

export const todoViewModel: TodoViewModel = new TodoViewModel();

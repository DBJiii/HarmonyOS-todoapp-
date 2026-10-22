/**
 * Preferences-backed persistence for todos and settings.
 *
 * This is the ONLY component that imports `@ohos.data.preferences`.
 * Every write calls `flush()` so data survives an app exit.
 *
 * Raw JSON is parsed into a plain `TodoJson` shape and then converted into
 * `Todo` domain objects. This keeps the observed (`@ObservedV2`) domain types
 * out of the serialisation path, and makes malformed / absent payloads safe.
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../common/Constants';
import { AppSettings, Todo } from '../model/Todo';

const DOMAIN: number = 0x0000;
const TAG: string = 'TodoRepository';

/** Plain, serialisable shape of a todo. All fields optional for tolerance. */
interface TodoJson {
  id?: string;
  title?: string;
  description?: string;
  urgency?: number;
  significance?: number;
  deadline?: number;
  completed?: boolean;
  createdAt?: number;
  updatedAt?: number;
}

export class TodoRepository {
  private static context: common.Context | undefined = undefined;

  /** Called once from EntryAbility so the store can be opened lazily. */
  static init(context: common.Context): void {
    TodoRepository.context = context;
  }

  private static openStore(): preferences.Preferences | undefined {
    const ctx: common.Context | undefined = TodoRepository.context;
    if (ctx === undefined) {
      hilog.warn(DOMAIN, TAG, 'repository used before init');
      return undefined;
    }
    try {
      const options: preferences.Options = { name: Constants.PREF_STORE_NAME };
      return preferences.getPreferencesSync(ctx, options);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'open store failed: %{public}s', JSON.stringify(error));
      return undefined;
    }
  }

  static newId(): string {
    const rand: number = Math.floor(Math.random() * 100000);
    return `${Date.now()}_${rand}`;
  }

  private static fromJson(item: TodoJson): Todo {
    const todo = new Todo();
    todo.id = item.id ?? TodoRepository.newId();
    todo.title = item.title ?? '';
    todo.description = item.description ?? '';
    todo.urgency = item.urgency ?? Constants.DEFAULT_VALUE;
    todo.significance = item.significance ?? Constants.DEFAULT_VALUE;
    todo.deadline = item.deadline ?? 0;
    todo.completed = item.completed ?? false;
    todo.createdAt = item.createdAt ?? Date.now();
    todo.updatedAt = item.updatedAt ?? todo.createdAt;
    return todo;
  }

  private static toJson(todo: Todo): TodoJson {
    const json: TodoJson = {
      id: todo.id,
      title: todo.title,
      description: todo.description,
      urgency: todo.urgency,
      significance: todo.significance,
      deadline: todo.deadline,
      completed: todo.completed,
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt
    };
    return json;
  }

  static loadTodos(): Todo[] {
    const result: Todo[] = [];
    const store: preferences.Preferences | undefined = TodoRepository.openStore();
    if (store === undefined) {
      return result;
    }
    let raw: string = '[]';
    try {
      raw = store.getSync(Constants.KEY_TODOS, '[]') as string;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'read todos failed: %{public}s', JSON.stringify(error));
      raw = '[]';
    }
    let parsed: TodoJson[] = [];
    try {
      const value: Object = JSON.parse(raw);
      if (value instanceof Array) {
        parsed = value as TodoJson[];
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'malformed todos json, resetting defaults');
      parsed = [];
    }
    for (let i = 0; i < parsed.length; i++) {
      result.push(TodoRepository.fromJson(parsed[i]));
    }
    return result;
  }

  static async saveTodos(list: Todo[]): Promise<void> {
    const store: preferences.Preferences | undefined = TodoRepository.openStore();
    if (store === undefined) {
      return;
    }
    const dtoList: TodoJson[] = [];
    for (let i = 0; i < list.length; i++) {
      dtoList.push(TodoRepository.toJson(list[i]));
    }
    try {
      store.putSync(Constants.KEY_TODOS, JSON.stringify(dtoList));
      await store.flush();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'save todos failed: %{public}s', JSON.stringify(error));
    }
  }

  static loadSettings(): AppSettings {
    const settings = AppSettings.create();
    const store: preferences.Preferences | undefined = TodoRepository.openStore();
    if (store === undefined) {
      return settings;
    }
    try {
      settings.remindersEnabled =
        store.getSync(Constants.KEY_REMINDERS_ENABLED, Constants.DEFAULT_REMINDERS_ENABLED) as boolean;
      const lead: number =
        store.getSync(Constants.KEY_ADVANCE_LEAD_MINUTES, Constants.DEFAULT_ADVANCE_LEAD_MINUTES) as number;
      settings.advanceLeadMinutes = lead > 0 ? lead : Constants.DEFAULT_ADVANCE_LEAD_MINUTES;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'read settings failed: %{public}s', JSON.stringify(error));
      settings.remindersEnabled = Constants.DEFAULT_REMINDERS_ENABLED;
      settings.advanceLeadMinutes = Constants.DEFAULT_ADVANCE_LEAD_MINUTES;
    }
    return settings;
  }

  static async saveSettings(settings: AppSettings): Promise<void> {
    const store: preferences.Preferences | undefined = TodoRepository.openStore();
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(Constants.KEY_REMINDERS_ENABLED, settings.remindersEnabled);
      store.putSync(Constants.KEY_ADVANCE_LEAD_MINUTES, settings.advanceLeadMinutes);
      await store.flush();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'save settings failed: %{public}s', JSON.stringify(error));
    }
  }
}

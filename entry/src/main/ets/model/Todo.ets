/**
 * Domain types for the Quadrant Todo app.
 *
 * `Todo` and `AppSettings` are `@ObservedV2` classes so that individual
 * `@Trace` fields drive fine-grained UI refresh under State Management V2.
 */
import { Constants } from '../common/Constants';

/** The four Eisenhower quadrants of the plane. */
export enum Quadrant {
  Q1 = 'Q1',
  Q2 = 'Q2',
  Q3 = 'Q3',
  Q4 = 'Q4'
}

/** A single todo shown as a bar on the quadrant plane. */
@ObservedV2
export class Todo {
  @Trace id: string = '';
  @Trace title: string = '';
  @Trace description: string = '';
  /** Unbounded; maps to the horizontal (X) axis, quadrant divider at 50. */
  @Trace urgency: number = Constants.DEFAULT_VALUE;
  /** Unbounded; maps to the vertical (Y) axis, quadrant divider at 50. */
  @Trace significance: number = Constants.DEFAULT_VALUE;
  /** Optional epoch timestamp in ms; 0 means "no deadline". */
  @Trace deadline: number = 0;
  @Trace completed: boolean = false;
  @Trace createdAt: number = 0;
  @Trace updatedAt: number = 0;

  /** Factory that always returns a fully initialised instance. */
  static create(id: string, title: string, description: string, urgency: number,
    significance: number, deadline: number): Todo {
    const todo = new Todo();
    todo.id = id;
    todo.title = title;
    todo.description = description;
    todo.urgency = urgency;
    todo.significance = significance;
    todo.deadline = deadline;
    todo.completed = false;
    const now: number = Date.now();
    todo.createdAt = now;
    todo.updatedAt = now;
    return todo;
  }

  hasDescription(): boolean {
    return this.description.length > 0;
  }

  hasDeadline(): boolean {
    return this.deadline > 0;
  }

  isOverdue(now: number): boolean {
    return this.hasDeadline() && this.deadline < now && !this.completed;
  }
}

/** Editable payload used by the Create / Edit page. */
export class TodoDraft {
  title: string = '';
  description: string = '';
  urgency: number = Constants.DEFAULT_VALUE;
  significance: number = Constants.DEFAULT_VALUE;
  deadline: number = 0;
}

/** User configuration owned by the Settings page. */
@ObservedV2
export class AppSettings {
  @Trace remindersEnabled: boolean = Constants.DEFAULT_REMINDERS_ENABLED;
  @Trace advanceLeadMinutes: number = Constants.DEFAULT_ADVANCE_LEAD_MINUTES;

  static create(): AppSettings {
    const settings = new AppSettings();
    settings.remindersEnabled = Constants.DEFAULT_REMINDERS_ENABLED;
    settings.advanceLeadMinutes = Constants.DEFAULT_ADVANCE_LEAD_MINUTES;
    return settings;
  }
}

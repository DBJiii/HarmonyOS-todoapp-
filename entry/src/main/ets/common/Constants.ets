/**
 * Shared constants for the Quadrant Todo app.
 *
 * Single source of truth for the value domain, quadrant colors, plane
 * geometry, persistence keys and reminder defaults.
 */
export class Constants {
  // --- Value domain (urgency / significance) ---
  // The domain is unbounded: a value equals the bar's coordinate on the axis,
  // with 0,0 at the axes crossing (negative left/down, positive right/up).
  /** Quadrant divider / axis origin: a value at 0 belongs to the >= side. */
  static readonly DIVIDER: number = 0;
  static readonly DEFAULT_VALUE: number = 0;

  // --- Quadrant background colors ---
  static readonly COLOR_Q1: string = '#E53935'; // red    - urgent & significant
  static readonly COLOR_Q2: string = '#1E88E5'; // blue   - significant, not urgent
  static readonly COLOR_Q3: string = '#FB8C00'; // orange - neither
  static readonly COLOR_Q4: string = '#757575'; // grey   - urgent, not significant

  // --- Plane geometry (vp) ---
  /** Horizontal/vertical vp distance per single value unit at zoom == 1. */
  static readonly BASE_VP_PER_UNIT: number = 6;
  static readonly ZOOM_MIN: number = 0.1;
  static readonly ZOOM_MAX: number = 16;
  static readonly ZOOM_DEFAULT: number = 1;
  /** Multiplier applied by the on-screen zoom in / out buttons. */
  static readonly ZOOM_STEP: number = 1.25;
  /** Grid line spacing in value units. */
  static readonly GRID_STEP: number = 10;
  static readonly BAR_WIDTH: number = 144;
  static readonly BAR_HEIGHT: number = 48;

  // --- Persistence ---
  static readonly PREF_STORE_NAME: string = 'quadrant_todo_store';
  static readonly KEY_TODOS: string = 'todos_json';
  static readonly KEY_REMINDERS_ENABLED: string = 'reminders_enabled';
  static readonly KEY_ADVANCE_LEAD_MINUTES: string = 'advance_lead_minutes';

  // --- Defaults ---
  static readonly DEFAULT_REMINDERS_ENABLED: boolean = true;
  static readonly DEFAULT_ADVANCE_LEAD_MINUTES: number = 1440; // 1 day
  static readonly ADVANCE_LEAD_OPTIONS: number[] = [15, 60, 180, 720, 1440, 2880, 10080];

  // --- Reminder / notification ---
  static readonly BUNDLE_NAME: string = 'com.example.todoapp';
  static readonly ABILITY_NAME: string = 'EntryAbility';
  static readonly REMINDER_NOTIFICATION_ID_BASE: number = 1000;
  static readonly MILLIS_PER_MINUTE: number = 60000;

  // --- Animation ---
  static readonly COLOR_ANIM_DURATION: number = 320;
  static readonly PANEL_ANIM_DURATION: number = 160;
}

/** Create / Edit page modes. */
export const EDIT_MODE_CREATE: string = 'create';
export const EDIT_MODE_EDIT: string = 'edit';

/** Router params for the shared Create / Edit page (declared once). */
export interface EditParams {
  mode: string;
  todoId: string;
}

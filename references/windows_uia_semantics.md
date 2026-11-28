# Windows UIA Semantics & `agent-desktop` MCP Rules

Distilled platform semantics and failure-handling rules for operating the `agent-desktop` MCP server on Windows 10 1809+ / Windows Server 2019+.

## 1. Qualified Refs & Windows UIA Uniqueness (`AMBIGUOUS_TARGET` vs `STALE_REF`)

- **Ref Format**: Snapshot refs are qualified (`@<snapshot_id>:e<N>`, e.g., `@s8f3k2p9:e1`). Only addressable interactive elements receive refs; static text and inert containers do not.
- **Window-Wide Uniqueness Rule on Windows**: Unlike macOS (where refs carry native element pointers), Windows UIA resolves a ref **only** when it was the sole element in the entire window captured with that `(role, native_id, name, description)` tuple—counted across the whole window even below a `skeleton` or `max_depth` cut—and **exactly one** live element still matches at execution time.
  - **`AMBIGUOUS_TARGET` (`details.kind: "identity_not_unique"` or `"saved_ref_ambiguous"`)**: Returned when identical twin controls exist in the window (e.g., repeated `Delete` or `吸管` buttons across rows). Re-snapshotting or drilling `--root` into the row reads its static text labels (if `interactive_only=false`), **but does not make a twin button's `@ref` actionable**. To click one of identical twins, inspect its `bounds` from `desktop_snapshot(include_bounds=true)` and use `desktop_mouse_click(xy=[x, y])` (or inside `desktop_batch`).
  - **`identity_not_unique` from Partial Read Timeout**: Also occurs if a previous `desktop_snapshot` timed out before scanning the full window. Retake `desktop_snapshot` with a larger `timeout_ms`.
  - **`STALE_REF` (`details.kind: "saved_ref_absent"`)**: The target element disappeared, mutated, or was replaced by a `--root` sub-tree drill (drilling `--root @ref` keeps external refs and the root ref valid, but replaces all old refs inside that drilled subtree). Take a fresh `desktop_snapshot` and use the new ref.
  - **`TIMEOUT` (`details.kind: "resolution_identity_unknown"`)**: Live UIA read timed out before confirming element identity. Nothing was sent (`not_delivered`, `retry: "safe"`).

## 2. Action Delivery, Readback & Reformatting (`delivered_unverified` / `post_action_verification`)

- **Retry Discipline**: Retry or substitute an action **only** when `disposition.retry` is `"safe"` (`delivery: "not_delivered"`). Any other delivery state means the action may have landed—repeating it can double-click, double-submit, or undo a `desktop_toggle`.
- **`desktop_set_value` Reformatting Trap**: Stateful actions execute once and verify via UIA readback (`delivered_verified`). If an app reformats the input value (e.g., numeric rounding, unit suffix `10.00 m`, date formatting), `desktop_set_value` returns `ACTION_FAILED` with `details.kind: "post_action_verification"`. **Do NOT retry**—inspect `details.post_state` or call `desktop_get` to confirm the formatted value landed.
- **`desktop_type` Readback**: `desktop_type` synthesizes keystrokes via `SendInput` and returns `delivered_unverified` (`verification_scope: "unavailable"`) when the control exposes no readable UIA Text pattern selection. Confirm with `desktop_get` or a scoped `desktop_snapshot`.

## 3. Window State, Minimized `offscreen` Gotcha & Foreground Hygiene

- **Covered vs. Minimized Windows**: A window behind another window remains readable and drivable via semantic UIA ref actions. A **minimized** window is not: every element reports `offscreen` and ref actions fail.
- **`desktop_restore` Before `desktop_focus_window`**: When a window is minimized, call `desktop_restore(app="<executable_or_title>")` and re-snapshot. Do not call `desktop_focus_window` by reflex unless physical foreground input is needed, as it steals the active foreground.
- **Launch Target Names**: `desktop_launch` accepts an absolute executable path or a bare executable name under `System32` / Windows directory (`notepad` or `notepad.exe`), not a Start-menu display title. Use `desktop_list_apps` or `desktop_list_windows` to inspect running processes.

## 4. Headless Semantic UIA vs. Physical Foreground Input

- **Semantic UIA Actions**: `desktop_click`, `desktop_set_value`, `desktop_clear`, `desktop_select`, `desktop_toggle`, `desktop_check`, `desktop_uncheck`, `desktop_expand`, `desktop_collapse`, `desktop_scroll`, and `desktop_scroll_to` invoke UIA patterns directly without moving the physical cursor.
- **Foreground / Physical Input Actions**:
  - `desktop_type`, `desktop_right_click`, `desktop_double_click`, `desktop_triple_click`, `desktop_focus`, `desktop_hover`, `desktop_drag`, `desktop_mouse_click`, `desktop_mouse_move`, and `desktop_mouse_wheel` synthesize physical input or take focus.
  - `desktop_press` writes directly to the active foreground input queue (no per-process background key routing on Windows). Ensure the target window has `is_focused: true` before sending `desktop_press`.
  - Held-input primitives (`desktop_key_down`, `desktop_key_up`, `desktop_mouse_down`, `desktop_mouse_up`) fail closed with `ACTION_NOT_SUPPORTED` unless used inside supported drag/batch flows.

## 5. UIPI Elevation Boundaries & Session 1 Requirement

- **Interactive Session 1 Only**: Windows UIA and `SendInput` require the active signed-in user's desktop (`Session 1`). `Session 0` (background services/tasks), UAC Secure Desktop, and locked screens cannot be observed or driven.
- **UIPI (`E_ACCESSDENIED`)**: Windows enforces User Interface Privilege Isolation (UIPI) without a permission popup (`desktop_permissions` reports `not_required`). A medium-integrity agent process cannot inject input into an elevated (Administrator) window or system dialog. If an action fails with `E_ACCESSDENIED` or input is silently blocked by an elevated modal, stop and ask the user to dismiss or handle the elevated window.

## 6. Chromium / Electron Settle Timing & Surfaces

- **Settle Timeout (`timeout_ms`)**: Chromium, Electron, and WebView2 apps expose thin or empty UIA trees while hydrating. Pass a larger `timeout_ms` (e.g., `5000`–`10000`) to `desktop_snapshot` or use `desktop_wait` rather than concluding the tree is empty.
- **Windows Surfaces**: `desktop_list_surfaces` and `desktop_snapshot(surface=...)` support `window`, `focused`, `sheet` (Chromium modals), and `menu` (open context/app menus). Windows does not expose a separate `menubar` surface.
- **System Shell Surfaces**: `desktop_open_system_surface` supports `start-menu`, `taskbar`, `system-tray`, `system-tray-overflow`, and `action-center` (use `action-center`, not `quick-settings`).

## 7. Blocked System Shortcuts

- The following destructive or session-disrupting combos (and their modifier supersets) are blocked by default without `force=true`:
  `alt+f4`, `win+l`, `win+d`, `alt+tab`, `win+r`, `win+x`, `win+e`, `ctrl+shift+esc`.
- On Windows, `cmd` and `meta` map to the Windows key (`Win`), so `meta+c` triggers a shell shortcut—always use `ctrl+c` / `ctrl+v` / `ctrl+a` / `ctrl+s` / `ctrl+z`.

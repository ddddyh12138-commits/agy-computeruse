---
name: open-computer-use
description: >-
  Primary Windows desktop and hybrid 3D/CAD GUI automation skill. Orchestrates
  agent-desktop MCP (Session 1 batch execution, UIA snapshots, screen=0 capture,
  lifecycle waits) as the primary engine with open-computer-use MCP as fallback,
  powered by zero-dependency PowerShell SoM outer-ruler grids, UTF-8 UIA parsing,
  and sub-200ms pixel-diff verification.
---

# Windows Desktop & Hybrid 3D GUI Automation

## 1. Engine Routing & Concurrency Rules

- **Primary (`agent-desktop` MCP)**: Use for all Session 1 GUI operations: `desktop_launch(activate=true)`, `desktop_list_windows`, `desktop_batch`, `desktop_snapshot(include_bounds=true)`, `desktop_find`, `desktop_get`, `desktop_wait`, `desktop_mouse_wheel`, and `desktop_screenshot(screen=0)`.
- **Fallback (`open-computer-use` MCP)**: Use only for simple single-step Win32/Electron element-index clicks (`get_app_state` -> `click`). **Never** use `get_app_state` on localized Qt apps (fails with `\u009c` JSON error) and **never** mix `get_app_state` + `type_text` on custom Qt SpinBoxes (resets focus to top `Name` box).
- **Session 0 Isolation Ban**: Never use `run_command` to launch GUI apps (`Start-Process`) or send `SendInput` — `run_command` runs outside the interactive Session 1 desktop (`FG_HWND=0`).
- **Cheap Probe First**: Check single control state/text with `desktop_find` / `desktop_get` / `desktop_wait` before pulling full snapshots or screenshots.
- **Read-Only Parallel, Mutating Serial**: Run read-only observations (`desktop_list_windows`, `desktop_snapshot`, `desktop_screenshot`) in parallel when needed. **Never** run `desktop_batch` or `desktop_drag` in parallel with `desktop_screenshot` or clicks.

## 2. Three-Tier Coordinate Volatility Model

1. **Tier 1 (Session-Static while Maximized)**: Lock the target app maximized (`desktop_maximize`) at start. Main toolbar (`Reset`, `Run`, `Stop`, `Save`) and left library panel coordinates can be cached for the session.
2. **Tier 2 (Panel-Dynamic)**: Right-hand property panels and modal dialogs shift whenever objects change or sections expand/collapse. Refresh via `desktop_snapshot(root="@panel_ref", include_bounds=true)` + `scripts/parse_uia.ps1 -NameFilter ...` without taking screenshots.
3. **Tier 3 (Viewport-Volatile)**: 3D canvas objects, control points, and paths invalidate on **any** pan, zoom, or drag. **Zero-Eyeballing Rule**: for any target `<30px` or after any viewport change, re-measure on the latest `screen=0` screenshot with `scripts/som_grid.ps1`.

## 3. Text & Numeric Input Decision Tree (IME & Qt Safe)

1. **Priority 1 (Unique UIA `@ref`)**: `desktop_set_value` (bypasses focus, clipboard, and Chinese IME).
2. **Priority 2 (Chinese / Long Strings / Standard Fields)**: Inside `desktop_batch`: `clipboard-set(text)` -> `wait(80)` -> `mouse-click(xy)` -> `wait(80)` -> `press(ctrl+a)` -> `press(ctrl+v)` -> `press(return)` -> `wait(150)`.
3. **Priority 3 (Qt SpinBoxes where `ctrl+v` fails)**: `mouse-click(xy, count=2)` -> `press(ctrl+a)` -> `press(backspace)` -> plain digit/minus `press` sequence. If single-letter hotkeys (`a`/`s`/`q`/`-`) are swallowed by Chinese IME, click UI buttons instead or toggle English IME first.

## 4. Closed-Loop Batching, Focus & Circuit Breaker

- **Single-Process Closed Loop**: Pack deterministic multi-step sequences + `wait` + trailing `screenshot(screen=0)` into one `desktop_batch(stop_on_error=true)` call (`<64` commands). See `references/batch_recipes.md`.
- **Pre-Batch Focus & UIPI Guard**: Verify `is_focused: true` via `desktop_list_windows()`. If unfocused, click the app's taskbar button (`desktop_snapshot(surface="taskbar", include_bounds=true)` + `parse_uia.ps1 -Mode taskbar`) or an uncovered app region. If `E_ACCESSDENIED` / elevated popup (UIPI) blocks input, stop and ask the user to dismiss it.
- **2-Try Gesture Rule & 3-Turn Circuit Breaker**: If a 3D canvas drag/snap fails twice, switch to numeric/Eyedropper controls (`references/cad_3d_patterns.md`). If `scripts/verify_diff.ps1` reports `NO_CHANGE` twice in a row, **halt blind clicking** and run full diagnostics (`desktop_list_windows` + `desktop_screenshot(screen=0)` for hidden modals, focus loss, IME, or sticky toolbar icons).
- **Checkpoints, Undo & Rolling Scratch Hygiene**: Press `ctrl+s` before high-risk linking/runs; press `ctrl+z` immediately on misdrops (critical for quota-limited Express apps). Store rolling artifacts in `<ArtifactDir>/scratch/gui/` (`prev_screen.png`, `latest_screen.png`, `latest_grid.png`, `diff_crop.png`, `latest_uia.json`).

## 5. Helper Scripts (`scripts/`, Zero-Dependency PowerShell) & References

- **`scripts/som_grid.ps1`**: Outer 28px zero-occlusion ruler (`-Step`), `-Scale 2|3` nearest-neighbor zoom, `-Overview` (`0.5x` fast full-screen), `-Regions "name:x0,y0,x1,y1,step;..."` multi-ROI stitch, `-Markers "x,y:label;..."` crosshair preview, and `-SnapshotJson` SoM boxes.
- **`scripts/parse_uia.ps1`**: Clean UTF-8 parser for `desktop_snapshot(include_bounds=true)` files with `-NameFilter` regex, `-Mode all|panel|dialog|taskbar`, and `-BatchClick` JSON output.
- **`scripts/verify_diff.ps1`**: Sub-200ms `LockBits` pixel diff (`-Before` vs `-After`) outputting `CHANGED_PCT`, `DIFF_BBOX`, `STATUS=NO_CHANGE|CHANGED|MAJOR_CHANGE`, and optional `-CropDiffPath`.
- **References**: Read `references/batch_recipes.md` for copy-ready `desktop_batch` JSON templates and `references/cad_3d_patterns.md` for 3D/FlexSim/CAD rules.

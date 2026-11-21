# `desktop_batch` Golden Recipes (`agent-desktop`)

All recipes use `agent-desktop:desktop_batch` with `stop_on_error: true` and max **64 commands** per call.
Use flat `args` keys matching the tool schema (`xy: "X,Y"`, `combo: "ctrl+a"`, `from_xy`, `to_xy`). Never use `mouse-down`/`mouse-up` (unsupported in stateless mode).

## Recipe 1: Single-Process Action + Wait + Trailing Screenshot

Combines actions, settle/event wait, and phase-boundary capture in **one** MCP call:

```json
[
  {"command": "mouse-click", "args": {"xy": "120,65"}},
  {"command": "wait", "args": {"ms": 150}},
  {"command": "screenshot", "args": {"screen": 0, "output_path": "C:/.../scratch/gui/latest_screen.png"}}
]
```

For dialog triggers, swap `wait(ms)` with `{"command": "wait", "args": {"event": "window-opened", "timeout": 5000}}`.

## Recipe 2: Property Panel Multi-Field Numeric Input

### Variant A: Clipboard Paste (Standard Fields & Chinese Text)

```json
[
  {"command": "clipboard-set", "args": {"text": "-9"}},
  {"command": "wait", "args": {"ms": 80}},
  {"command": "mouse-click", "args": {"xy": "2310,415"}},
  {"command": "wait", "args": {"ms": 80}},
  {"command": "press", "args": {"combo": "ctrl+a"}},
  {"command": "press", "args": {"combo": "ctrl+v"}},
  {"command": "press", "args": {"combo": "return"}},
  {"command": "wait", "args": {"ms": 150}}
]
```

### Variant B: Qt SpinBox Direct Keystrokes (When `ctrl+v` Is Ignored)

```json
[
  {"command": "mouse-click", "args": {"xy": "2310,415", "count": 2}},
  {"command": "wait", "args": {"ms": 80}},
  {"command": "press", "args": {"combo": "ctrl+a"}},
  {"command": "press", "args": {"combo": "backspace"}},
  {"command": "press", "args": {"combo": "-"}},
  {"command": "press", "args": {"combo": "9"}},
  {"command": "press", "args": {"combo": "return"}},
  {"command": "wait", "args": {"ms": 150}}
]
```

## Recipe 3: Eyedropper (`吸管`) Batch Semantic Linking

Preferred over 3D canvas `A`-links when connecting `ControlPoint -> Queue (Location)` or `Queue 输入端口`:

```json
[
  {"command": "mouse-click", "args": {"xy": "2480,612"}},
  {"command": "wait", "args": {"ms": 100}},
  {"command": "mouse-click", "args": {"xy": "905,745"}},
  {"command": "wait", "args": {"ms": 150}}
]
```

## Recipe 4: 3D Viewport Safe Drag, Right-Click Break & Box-Select Clear

Use `duration >= 400` and `drop_delay >= 500` so 3D canvas drop targets register reliably:

```json
[
  {"command": "drag", "args": {"from_xy": "140,320", "to_xy": "905,745", "duration": 500, "drop_delay": 500}},
  {"command": "wait", "args": {"ms": 200}},
  {"command": "mouse-click", "args": {"xy": "600,500", "button": "right"}},
  {"command": "mouse-click", "args": {"xy": "600,500", "modifiers": ["shift"]}}
]
```

## Recipe 5: Taskbar Focus Recovery + Screen Capture

When `desktop_list_windows()` shows `is_focused: false`, resolve the taskbar button center via `desktop_snapshot(surface="taskbar", include_bounds=true)` + `parse_uia.ps1 -Mode taskbar`:

```json
[
  {"command": "mouse-click", "args": {"xy": "1812,1564"}},
  {"command": "wait", "args": {"ms": 200}},
  {"command": "screenshot", "args": {"screen": 0, "output_path": "C:/.../scratch/gui/latest_screen.png"}}
]
```

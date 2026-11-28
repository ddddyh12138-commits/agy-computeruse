<p align="center">
  <a href="README.md">简体中文</a> | <strong>English</strong>
</p>

# Windows Hybrid Computer Use Skill (`agy-computer-use`)

A battle-tested **Windows Desktop & Hybrid 3D / Industrial Software (FlexSim 2022, CAD, Qt Desktop) Computer Use Skill and zero-dependency toolkit**, built and refined on top of **[vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop)**.

Distilled from long-horizon 3D simulation modeling workflows (multi-AGV and sorting systems in FlexSim), this project solves the toughest Windows Computer Use failure modes: **high VLM latency, Session 0 isolation (`FG_HWND=0`), high-DPI (1.5x/2x) coordinate drift, localized Qt UIA crashes, Chinese IME keystroke swallowing, and silent no-op clicks**—while shipping a dedicated **FlexSim 2022 Three-Layer Dual-Channel Automation Suite**.

---

## One-Click Deployment (AI Agents & Humans)

> [!TIP]
> **Send this repository URL directly to your AI Agent (Antigravity / Cursor / Claude Code, etc.), and it can deploy and verify the entire setup automatically:**

```powershell
# 1. Clone the repository into a local scratch/project directory
git clone https://github.com/ddddyh12138-commits/agy-computer-use.git "$env:USERPROFILE\.gemini\antigravity\scratch\agy-computer-use"

# 2. Run the idempotent installer (installs agent-desktop, deploys both skills & scripts, registers MCP, and runs self-checks)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\antigravity\scratch\agy-computer-use\install.ps1"
```

What `install.ps1` does automatically:
1. **Installs Core Executor**: Checks for `agent-desktop` CLI (`vercel-labs/agent-desktop`) and installs it globally via `npm install -g agent-desktop` if missing (requires Node.js >= 18).
2. **Deploys Dual Skills & Toolkits**:
   - Installs `open-computer-use` to `%USERPROFILE%\.gemini\config\skills\open-computer-use`;
   - Installs `flexsim-automation` and its dual-channel scripts to `%USERPROFILE%\.gemini\config\skills\flexsim-automation` (pass `-SkipFlexSimSkill` to opt out).
3. **Registers MCP Server**: Safely merges `agent-desktop` (`agent-desktop mcp --headed`) into `%USERPROFILE%\.gemini\config\mcp_config.json` without overwriting existing MCP entries.
4. **Runs End-to-End Self-Check**: Verifies `agent-desktop status` plus PowerShell & Python syntax across all scripts, printing `READY_TO_USE` when ready.

---

## Core Features

1. **Dual-Engine Routing & Single-Process Batching (3–5× Speedup)**
   - Uses `agent-desktop` MCP in interactive Session 1 as the primary engine, packing multi-step actions, settle `wait`s, and boundary `screenshot`s into a single `desktop_batch` call (`~640ms` round-trip) instead of slow click-and-capture loops.
   - Strictly forbids launching GUI apps or sending `SendInput` from non-interactive `Session 0` terminals.
   - Enforces **read-only parallel, mutating serial** concurrency, **Windows UIA twin-control / readback rules** ([references/windows_uia_semantics.md](references/windows_uia_semantics.md)), and a **three-tier coordinate volatility model**.

2. **Zero-Occlusion High-Precision Grounding ([scripts/som_grid.ps1](scripts/som_grid.ps1))**
   - **28px Outer Ruler Frame**: Axis labels and ticks align strictly to gridlines without occluding viewport edges or causing off-by-one-column (50px) misreads.
   - **`-Scale 2|3` Crisp Nearest-Neighbor Zoom**: Enlarges `<15px` 3D control points and icons while preserving true screen coordinates.
   - **`-Overview` / `-Regions` / `-Markers`**: Supports `0.5x` fast overview downsampling, multi-ROI single-image stitching, and crosshair target previews.

3. **UTF-8 UIA Tree Filter ([scripts/parse_uia.ps1](scripts/parse_uia.ps1)) & Sub-200ms Pixel Diff ([scripts/verify_diff.ps1](scripts/verify_diff.ps1))**
   - Bypasses localized Qt `\u009c` encoding crashes with `-Mode taskbar|dialog|panel` presets and `-BatchClick` JSON output.
   - Inline C# `Bitmap.LockBits` pixel comparison paired with a **2-consecutive `NO_CHANGE` circuit breaker** to catch focus loss, Chinese IME hijacking, or elevated UIPI modals immediately.

4. **FlexSim 2022 Three-Layer Dual-Channel Suite ([skills/flexsim-automation](skills/flexsim-automation/SKILL.md))**
   - **Environment & License Probe (`flexsim_env_probe.ps1`)**: Detects FlexSim install path, running processes, MCP health, and whether headless CLI FlexScript is unlocked (Full License vs. Express Edition).
   - **Channel 1 — Headless CLI FlexScript (`flexsim_script_runner.py`)**: Automates model inspection, simulation runs, and CSV/JSON statistics export via `/maintenance nogui_disablemsg_runscript` on licensed editions.
   - **Channel 2 — `.fsx` XML Offline Topology Auditor (`flexsim_fsx_inspector.py`)**: Zero-dependency XML parser that extracts object coordinates and `A` (flow) / `S` (center-port) connections to verify wiring and detect leftover operator links in comparison experiments.
   - **Channel 3 — FlexSim GUI Batch Recipes & Disk Verifier (`flexsim_gui_helper.ps1`)**: Generates `desktop_batch` JSON for IME-safe field pasting, Qt `SpinBox` keystrokes, Eyedropper (`吸管`) linking, 3D dragging, and `.fsm` disk-save verification.
   - See [docs/flexsim-best-practices.md](docs/flexsim-best-practices.md) for architectural details.

---

## Directory Structure

```text
agy-computer-use/
├── install.ps1                                # One-click idempotent installer & self-check
├── SKILL.md                                   # Primary Windows desktop protocol (with FlexSim routing)
├── references/
│   ├── batch_recipes.md                       # 5 golden desktop_batch JSON templates
│   ├── cad_3d_patterns.md                     # 3D / CAD / FlexSim 2022 modeling & verification rules
│   └── windows_uia_semantics.md               # Windows UIA twin-ref, readback & UIPI semantics
├── scripts/
│   ├── som_grid.ps1                           # Outer ruler / zoom / overview / multi-ROI / crosshairs
│   ├── parse_uia.ps1                          # UTF-8 UIA filter & batch-click JSON generator
│   └── verify_diff.ps1                        # LockBits pixel diff & diff-bbox auto-cropper
├── skills/
│   └── flexsim-automation/                    # Dedicated FlexSim 2022 automation skill
│       ├── SKILL.md                           # FlexSim dual-channel routing & closed-loop SOP
│       └── scripts/
│           ├── flexsim_env_probe.ps1          # Install, process, MCP & license-mode probe
│           ├── flexsim_fsx_inspector.py       # .fsx XML topology & isolation auditor
│           ├── flexsim_script_runner.py       # Licensed FlexScript CLI wrapper
│           └── flexsim_gui_helper.ps1         # FlexSim batch recipe generator & .fsm disk verifier
├── docs/
│   └── flexsim-best-practices.md              # Antigravity 4-layer routing & FlexSim best practices
├── LICENSE                                    # MIT License
├── README.md                                  # Simplified Chinese documentation
└── README.en.md                               # English documentation
```

---

## Standalone Tool Examples

```powershell
# 1) Probe FlexSim 2022 environment & license channel (Full CLI vs. Express GUI)
powershell -ExecutionPolicy Bypass -File .\skills\flexsim-automation\scripts\flexsim_env_probe.ps1 -ProbeScriptMode

# 2) Audit an .fsx XML model and verify an operator is completely disconnected
py .\skills\flexsim-automation\scripts\flexsim_fsx_inspector.py model.fsx --check-isolated "Operator1"

# 3) Generate a Qt SpinBox-safe desktop_batch JSON recipe
powershell -ExecutionPolicy Bypass -File .\skills\flexsim-automation\scripts\flexsim_gui_helper.ps1 -Recipe spinbox-num -X 2310 -Y 415 -Text "-9"

# 4) Stitch multiple ROIs with outer rulers and target crosshairs
powershell -ExecutionPolicy Bypass -File .\scripts\som_grid.ps1 -InputPath screen.png -OutputPath multi.png -Regions "toolbar:60,30,420,120,40;cp1:800,780,940,900,20,2" -Markers "864,830:CP1"

# 5) Run sub-200ms pixel diff and crop the changed region
powershell -ExecutionPolicy Bypass -File .\scripts\verify_diff.ps1 -Before prev.png -After latest.png -CropDiffPath diff_crop.png
```

---

## License

[MIT](LICENSE) © 2026 ddddyh

---
name: flexsim-automation
description: >-
  FlexSim 2022 专属自动化与仿真验证技能。通过三层双通道架构（CLI FlexScript 脚本通道、`.fsx` XML 离线模型拓扑审计通道、基于 agent-desktop + 零遮挡 SoM 标尺的混合 GUI 通道）高效操控 FlexSim 2022（`.fsm`/`.fsx`），覆盖发生器/暂存区/处理器/吸收器/任务分配器/操作员/AGV 建模、端口连线、参数配置、仿真运行与统计核验。触发关键词：FlexSim、.fsm、.fsx、离散事件仿真、仿真建模、任务分配器、操作员、吞吐量。
---

# FlexSim 2022 最佳双通道控制规范

本技能专为 **Windows + Antigravity + FlexSim 2022** 设计，遵循“能程序化绝不点屏幕，必须点屏幕时用原子批处理 + UIA + 零遮挡标尺闭环”的原则。

## 1. 三层双通道路由策略

在开始任何 FlexSim 任务前，先运行环境探测脚本确认当前通道状态：

```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.gemini\config\skills\flexsim-automation\scripts\flexsim_env_probe.ps1" -ProbeScriptMode
```

按探测结果路由：

1. **通道 1：FlexScript CLI 脚本通道（`MODE=FULL_SCRIPT_READY`，完整授权版优先）**
   - 适用：批量改参、自动化仿真实验（`Reset` -> `Run` -> 导出 `input`/`output`/`content`/`staytime` 统计）、对象与端口结构读取。
   - 工具：`scripts/flexsim_script_runner.py`。
2. **通道 2：`.fsx` XML 离线模型审计通道（全版本通用，零误差拓扑核验）**
   - 适用：核对复杂模型的对象坐标、参数与 `A`（输入/输出）/ `S`（居中端口）连线拓扑，或排查对比实验中多余操作员/任务分配器是否仍有残留连接。
   - 做法：在 FlexSim 中将模型另存为 `.fsx`（或直接读取已有 `.fsx`），运行 `scripts/flexsim_fsx_inspector.py`。
3. **通道 3：混合 UIA + 外置 SoM + 批处理 GUI 通道（`MODE=EXPRESS_OR_GUI_ONLY` 或 3D 交互必用）**
   - 适用：Express 免费评估版（无头脚本与脚本控制台受限）、3D 视口建模与拖拽、实时观察仿真动画与右侧属性面板调参。
   - 引擎：以 `agent-desktop` MCP 为主引擎（`desktop_launch`、`desktop_maximize`、`desktop_batch`、`desktop_snapshot`、`desktop_screenshot(screen=0)`），配合 `open-computer-use` 的 `scripts/som_grid.ps1`、`scripts/parse_uia.ps1`、`scripts/verify_diff.ps1` 及本技能的 `scripts/flexsim_gui_helper.ps1`。

---

## 2. FlexSim 2022 GUI 黄金闭环铁律

### 2.1 启动、窗口锁定与进程卫生
- **严禁通过 `run_command` 启动 GUI**：`run_command` 位于隔离的 Session 0，必须通过 `agent-desktop:desktop_launch`（传入 `flexsim.exe` 路径）或双击 `.fsm` 文件打开。
- **开局最大化锁定**：打开后立即调用 `desktop_maximize`，确保左侧对象库面板和顶部主工具栏（`重置`、`运行`、`停止`、`保存`）坐标在会话内稳定。
- **读写并发规则**：只读探测（`desktop_list_windows`、`desktop_snapshot`、`desktop_screenshot`）可并发；**`desktop_batch` 与 `desktop_drag` 绝不与截图或点击并发**。

### 2.2 三层坐标易变性模型
1. **第一层（会话静态）**：最大化后的顶部工具栏与左侧对象库。
2. **第二层（面板动态）**：右侧属性面板会随选中对象及折叠组（`统计`、`模板`、`外观`）变化而上下位移。**折叠面板请从下往上收起**，以保持上方控件 Y 坐标稳定，并用 `desktop_snapshot(root="@panel_ref", include_bounds=true)` + `parse_uia.ps1` 刷新坐标。
3. **第三层（3D 视口极易变）**：任何平移、缩放或拖拽后 3D 对象坐标即失效。**禁止盲猜坐标**：目标小于 `30px`（尤其是 `<15px` 的控制点或路径）时，先将鼠标移至附近并调用 `desktop_mouse_wheel(dy=8..10)` 放大，截取 `screen=0` 后用 `som_grid.ps1 -Scale 2 -Step 20` 精确读数。

### 2.3 中文输入法（IME）与 Qt SpinBox 三级录入决策树
1. **优先（唯一 UIA `@ref`）**：`desktop_set_value`（直接写入值，绕过焦点与中文输入法；若返回 `post_action_verification`，切勿盲目重试，先读 `post_state` 确认是否仅因自动补全单位/小数位触发）。
2. **次选（标准输入框与中文名称）**：使用 `flexsim_gui_helper.ps1 -Recipe paste-field` 生成 `clipboard-set` -> `mouse-click` -> `ctrl+a` -> `ctrl+v` -> `return` 批处理。
3. **兜底（Qt SpinBox 拒绝粘贴时）**：使用 `flexsim_gui_helper.ps1 -Recipe spinbox-num` 生成双击 -> `ctrl+a` -> `backspace` -> 纯数字/负号按键序列批处理。

### 2.4 端口连线与属性吸管规则
- **属性面板 `吸管` 优先于 3D 画布拖拽连线**：在 3D 画布强行跨对象拖拽连线容易触发 `Exception Caught in defaultdragconnection function`。连接 `控制点 -> 暂存区` 或设置 `使用运输工具` 引用时，优先点击属性面板的 `吸管` 图标再点目标 3D 对象（可用 `flexsim_gui_helper.ps1 -Recipe eyedropper-link`）。
- **警惕粘滞工具栏图标**：FlexSim 的 `A / S / Q` 端口连接按钮会保留上次从下拉菜单选择的模式，使用前务必核对当前激活图标。
  - `A` 模式：流连接（上游 -> 下游）。
  - `S` 模式：居中端口连接（绑定 `任务分配器` / `操作员` 到固定资源）。
  - `Q` 模式：断开端口连接。
- **对比实验彻底隔离铁律**：做单/双操作员或任务分配器对比实验时，仅清空引用字段**不能**禁用多余操作员，必须用 `Q` 模式彻底断开多余操作员/任务分配器的 `S` 连接，并建议另存 `.fsx` 用 `flexsim_fsx_inspector.py --check-isolated` 验证无残留连接。

### 2.5 仿真时钟、Express 上限与磁盘保存核验
- **现实等待 `ms` ≠ 仿真时间秒数**：绝不能把 `desktop_wait(10000)` 当作仿真跑了 10 秒！必须通过 `重置` -> `运行` -> 观察模型顶部仿真时钟（或设 `停止时间`）-> `停止`，再读取各对象真实统计（`输入`、`输出`、`当前内容`、`停留时间`、状态百分比）。
- **Express 版防护**：Express 版限制 **30 个 3D 对象** 且禁用脚本控制台/模型树/全局触发器。误放对象立即按 `ctrl+z` 撤销；每完成一个阶段（布局、参数、连线）立即按 `ctrl+s` 保存。
- **强制磁盘保存校验**：每次 `ctrl+s` 后，必须用 `flexsim_gui_helper.ps1 -VerifyFsmPath "<path>"` 或 `Get-Item` 核验 `.fsm` 文件的 `Length` 与 `LastWriteTime` 已真实刷新。

---

## 3. 配套脚本速查

| 脚本路径（均位于本技能 `scripts/` 下） | 核心用途 |
| :--- | :--- |
| `flexsim_env_probe.ps1` | 探测 FlexSim 安装路径、运行中进程、DPI、MCP 状态及是否支持 CLI 脚本模式 |
| `flexsim_fsx_inspector.py` | 零依赖解析 `.fsx` XML 模型，输出对象清单、坐标、A/S 端口拓扑并检查残留隔离连接 |
| `flexsim_script_runner.py` | 完整授权版 FlexScript CLI 自动化封装（导出拓扑、运行并导出统计 CSV/JSON） |
| `flexsim_gui_helper.ps1` | 生成符合 `agent-desktop:desktop_batch` 规范的 JSON 配方，并核验 `.fsm` 磁盘落盘 |

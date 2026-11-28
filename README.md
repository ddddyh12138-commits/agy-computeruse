# Windows Hybrid Computer Use Skill (`agy-computeruse`)

一套基于开源项目 **[vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop)** 深度优化与实战调教的 **Windows 桌面及复杂 3D / 工业软件（FlexSim 2022、CAD、Qt 桌面端）** AI Agent Computer Use 增强技能与零依赖工具链。

本项目从真实复杂 3D 建模（FlexSim 多 AGV 与分拣仿真）长程实操痛点中提炼重构而成，核心解决传统 Computer Use 在 Windows 上普遍存在的**高延迟、Session 0 隔离失效、1.5x/2x 高分屏目测偏移、Qt 中文 UIA 崩溃、中文输入法吞键与静默空操作**问题，并提供完整的 **FlexSim 2022 三层双通道控制套件**。

---

## 一键部署（AI Agent & 人类通用）

> [!TIP]
> **如果你把本仓库链接发给了你的 AI Agent（Antigravity / Cursor / Claude Code 等），AI 可直接按以下步骤全自动完成部署并跑通：**

```powershell
# 1. 克隆本仓库到本地临时/项目目录
git clone https://github.com/ddddyh12138-commits/agy-computeruse.git "$env:USERPROFILE\.gemini\antigravity\scratch\agy-computeruse"

# 2. 运行一键幂等安装脚本（自动安装 agent-desktop、部署双技能与脚本、注册 MCP 并自检）
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\antigravity\scratch\agy-computeruse\install.ps1"
```

安装脚本 `install.ps1` 会自动完成以下 4 件事：
1. **安装底层执行器**：检测本机是否已安装 `agent-desktop` CLI（`vercel-labs/agent-desktop`），若未安装则自动运行 `npm install -g agent-desktop`（需本机有 Node.js >= 18）。
2. **部署双技能与工具链**：
   - 将通用桌面技能 `open-computer-use` 部署至 `%USERPROFILE%\.gemini\config\skills\open-computer-use`；
   - 将 FlexSim 专属技能 `flexsim-automation` 及双通道脚本部署至 `%USERPROFILE%\.gemini\config\skills\flexsim-automation`（可加 `-SkipFlexSimSkill` 跳过）。
3. **注册 MCP Server**：自动在 `%USERPROFILE%\.gemini\config\mcp_config.json` 中安全合并写入 `agent-desktop`（`agent-desktop mcp --headed`），不覆盖你已有的其他 MCP 配置。
4. **运行全链路自检**：自动调用 `agent-desktop status` 并校验全部 PowerShell 与 Python 脚本语法，输出 `READY_TO_USE` 即代表就绪。

---

## 核心特性

1. **双引擎路由与单进程闭环提速（3–5× 提速）**
   - 以运行在交互式 Session 1 桌面的 `agent-desktop` MCP 为主引擎，将多步操作、`wait` 与边界 `screenshot` 打包进单次 `desktop_batch`（`~640ms` 完成），告别“点一次截一次全屏”的低效循环。
   - 明确禁止通过非交互终端（Session 0，`FG_HWND=0`）调用 `Start-Process` 或 `SendInput`。
   - 制定**只读观测并行、写入操作串行**的并发纪律、**Windows UIA 孪生控件/防错重规则**（[references/windows_uia_semantics.md](references/windows_uia_semantics.md)）与**三层坐标易失性模型**。

2. **高精度零遮挡坐标定位工具链 ([scripts/som_grid.ps1](scripts/som_grid.ps1))**
   - **28px 外置标尺边框**：坐标文字与刻度线严格居中对齐网格线，消除传统网格标签遮挡导致的 1 列（50px）误读。
   - **`-Scale 2|3` 无模糊像素放大**：`NearestNeighbor` 放大配合真实屏幕坐标标尺，精准拾取 `<15px` 3D 控制点与图标。
   - **`-Overview` / `-Regions` / `-Markers`**：支持 `0.5x` 概览图、多 ROI 单次拼图与拟落点十字准星预览。

3. **UTF-8 UIA 树精准过滤 ([scripts/parse_uia.ps1](scripts/parse_uia.ps1)) & 毫秒级差分校验 ([scripts/verify_diff.ps1](scripts/verify_diff.ps1))**
   - 绕过本地化 Qt 应用的 `\u009c` 编码崩溃，支持 `-Mode taskbar|dialog|panel` 与 `-BatchClick` JSON 输出。
   - 内联 C# `Bitmap.LockBits` 毫秒级对比前后截图，配合 **连续两次 `NO_CHANGE` 熔断协议** 秒级识别焦点丢失、中文 IME 劫持或 UIPI 提权弹窗。

4. **FlexSim 2022 专属三层双通道控制套件 ([skills/flexsim-automation](skills/flexsim-automation/SKILL.md))**
   - **环境与授权自动探测（`flexsim_env_probe.ps1`）**：一键探测安装路径、运行中进程、MCP 状态及是否支持无头 CLI 脚本（自动区分完整授权版 vs Express 评估版）。
   - **通道 1 — CLI FlexScript 自动化（`flexsim_script_runner.py`）**：完整授权版支持通过 `/maintenance nogui_disablemsg_runscript` 导出拓扑、跑仿真并输出统计 CSV/JSON。
   - **通道 2 — `.fsx` XML 离线模型拓扑审计（`flexsim_fsx_inspector.py`）**：零依赖解析 `.fsx` 模型，还原对象坐标与 `A`/`S` 端口连接，精准排查对比实验中的残留连接。
   - **通道 3 — FlexSim GUI 批处理配方与落盘核验（`flexsim_gui_helper.ps1`）**：一键生成抗中文 IME 粘贴、Qt `SpinBox` 逐键输入、`吸管` 连线、3D 拖拽及 `ctrl+s` `.fsm` 磁盘刷新校验 JSON。
   - 更多架构说明见：[docs/flexsim-best-practices.md](docs/flexsim-best-practices.md)。

---

## 目录结构

```text
agy-computeruse/
├── install.ps1                                # 一键全自动部署与全链路自检脚本
├── SKILL.md                                   # 通用桌面主控协议（含 FlexSim 路由联动）
├── references/
│   ├── batch_recipes.md                       # desktop_batch 5 套黄金 JSON 模板
│   ├── cad_3d_patterns.md                     # 3D / CAD / FlexSim 2022 实战防呆与核验规范
│   └── windows_uia_semantics.md               # Windows UIA 孪生控件、回读校验与 UIPI 规则
├── scripts/
│   ├── som_grid.ps1                           # 外置标尺 / 放大 / Overview / 多 ROI 拼图 / 准星工具
│   ├── parse_uia.ps1                          # UTF-8 UIA 树过滤与 Batch JSON 生成器
│   └── verify_diff.ps1                        # LockBits 像素差分与局部变化自动裁剪器
├── skills/
│   └── flexsim-automation/                    # FlexSim 2022 专属自动化技能包
│       ├── SKILL.md                           # FlexSim 三层双通道路由与黄金闭环 SOP
│       └── scripts/
│           ├── flexsim_env_probe.ps1          # 安装路径、进程、MCP 与授权通道探测
│           ├── flexsim_fsx_inspector.py       # .fsx XML 模型拓扑与隔离性审计器
│           ├── flexsim_script_runner.py       # 完整版 FlexScript CLI 自动化封装
│           └── flexsim_gui_helper.ps1         # FlexSim 批处理配方生成器与 .fsm 落盘校验
├── docs/
│   └── flexsim-best-practices.md              # Antigravity 四层路由与 FlexSim 最佳实践指南
├── LICENSE                                    # MIT License
└── README.md
```

---

## 配套工具独立调用示例

```powershell
# 1) 探测 FlexSim 2022 环境与授权通道（完整版 CLI vs Express GUI）
powershell -ExecutionPolicy Bypass -File .\skills\flexsim-automation\scripts\flexsim_env_probe.ps1 -ProbeScriptMode

# 2) 离线审计 .fsx 模型拓扑并检查“操作员1”是否已彻底断开端口
py .\skills\flexsim-automation\scripts\flexsim_fsx_inspector.py model.fsx --check-isolated "操作员1"

# 3) 生成 FlexSim Qt SpinBox 安全输入批处理 JSON 配方
powershell -ExecutionPolicy Bypass -File .\skills\flexsim-automation\scripts\flexsim_gui_helper.ps1 -Recipe spinbox-num -X 2310 -Y 415 -Text "-9"

# 4) 生成多 ROI 局部拼图并标注拟点击准星
powershell -ExecutionPolicy Bypass -File .\scripts\som_grid.ps1 -InputPath screen.png -OutputPath multi.png -Regions "toolbar:60,30,420,120,40;cp1:800,780,940,900,20,2" -Markers "864,830:CP1"

# 5) 毫秒级像素差分校验并裁剪变化局部
powershell -ExecutionPolicy Bypass -File .\scripts\verify_diff.ps1 -Before prev.png -After latest.png -CropDiffPath diff_crop.png
```

---

## License

[MIT](LICENSE) © 2026 ddddyh

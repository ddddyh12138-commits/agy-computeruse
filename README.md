# Windows Hybrid Computer Use Skill (`agy-computeruse`)

一套面向 **Windows 桌面及复杂 3D / 工业软件（如 FlexSim、CAD、Qt 桌面端）** 的 AI Agent Computer Use 实战技能与零依赖 PowerShell 工具链。

本项目从真实复杂 3D 建模（FlexSim 多 AGV 与分拣仿真）长程实操痛点中提炼重构而成，核心解决传统 Computer Use 在 Windows 上普遍存在的**高延迟、Session 0 隔离失效、1.5x/2x 高分屏目测偏移、Qt 中文 UIA 崩溃、中文输入法吞键与静默空操作**问题。

---

## 核心特性

1. **双引擎路由与单进程闭环提速（3–5× 提速）**
   - 以运行在交互式 Session 1 桌面的 `agent-desktop` MCP 为主引擎，将多步操作、`wait` 与边界 `screenshot` 打包进单次 `desktop_batch`（`~640ms` 完成），告别“点一次截一次全屏”的低效循环。
   - 明确禁止通过非交互终端（Session 0，`FG_HWND=0`）调用 `Start-Process` 或 `SendInput`。
   - 制定**只读观测并行、写入操作串行**的并发纪律与**三层坐标易失性模型**。

2. **高精度零遮挡坐标定位工具链 ([scripts/som_grid.ps1](scripts/som_grid.ps1))**
   - **28px 外置标尺边框**：坐标文字与刻度线严格居中对齐网格线，彻底消除传统网格标签落在格内导致的 1 列（50px）误读，且不遮挡原图边缘。
   - **`-Scale 2|3` 无模糊像素放大**：`NearestNeighbor` 放大配合真实屏幕坐标标尺，精准拾取 `<15px` 3D 控制点与图标。
   - **`-Overview` 低分概览模式**：自动将 `2560×1600` 降采样至 `0.5x`（像素量降至 1/4）并保留真实屏幕坐标标尺，大幅加快 VLM 读图速度。
   - **`-Regions` 多 ROI 单次拼图**：一次调用将工具栏、3D 视口、属性面板等多个局部区域带独立标尺拼接为单张图片。
   - **`-Markers` 十字准星预览**：高风险点击前在图上标注拟落点十字准星与坐标确认。

3. **UTF-8 UIA 树精准过滤 ([scripts/parse_uia.ps1](scripts/parse_uia.ps1))**
   - 绕过本地化 Qt 应用的 `\u009c` 编码崩溃，直接解析 `desktop_snapshot(include_bounds=true)` 输出。
   - 支持 `-NameFilter` 中英文父容器+控件名正则过滤、`-Mode taskbar|dialog|panel` 快捷预设、以及 `-BatchClick` 直接生成可粘贴的 `desktop_batch` JSON 片段。

4. **毫秒级像素差分无感校验 ([scripts/verify_diff.ps1](scripts/verify_diff.ps1))**
   - 基于内联 C# `Bitmap.LockBits` 内存扫描，快速对比批处理前后截图并输出 `CHANGED_PCT`、`CHANGED_PIXELS`、`DIFF_BBOX` 与 `STATUS`（`NO_CHANGE` / `CHANGED` / `MAJOR_CHANGE`）。
   - 支持 `-CropDiffPath` 自动裁剪变化区域供局部复核，配合 **3 轮无进展熔断协议** 秒级识别焦点丢失、中文 IME 劫持或 UIPI 提权弹窗拦截。

---

## 目录结构

```text
agy-computeruse/
├── SKILL.md                       # 主控协议（引擎路由、三层坐标模型、输入决策树、熔断规则）
├── references/
│   ├── batch_recipes.md           # desktop_batch 5 套黄金 JSON 模板
│   └── cad_3d_patterns.md         # 3D / CAD / FlexSim 6 条实战防呆模式
├── scripts/
│   ├── som_grid.ps1               # 外置标尺 / 放大 / Overview / 多 ROI 拼图 / 准星工具
│   ├── parse_uia.ps1              # UTF-8 UIA 树过滤与 Batch JSON 生成器
│   └── verify_diff.ps1            # LockBits 像素差分与局部变化自动裁剪器
├── LICENSE                        # MIT License
└── README.md
```

---

## 快速安装与使用

### 1. 安装为 Antigravity / AI Agent 技能

将本项目克隆或复制到本地技能目录（例如 `~/.gemini/config/skills/open-computer-use/`）：

```powershell
git clone https://github.com/ddddyh/agy-computeruse.git "$env:USERPROFILE\.gemini\config\skills\open-computer-use"
```

### 2. 配套工具独立调用示例

```powershell
# 1) 生成全局 0.5x 概览图（保留真实屏幕坐标外置标尺）
powershell -ExecutionPolicy Bypass -File .\scripts\som_grid.ps1 -InputPath screen.png -OutputPath overview.png -Overview

# 2) 单次生成多 ROI 局部拼图并标注拟点击准星
powershell -ExecutionPolicy Bypass -File .\scripts\som_grid.ps1 -InputPath screen.png -OutputPath multi.png -Regions "toolbar:60,30,420,120,40;cp1:800,780,940,900,20,2" -Markers "864,830:CP1"

# 3) 从 UIA 快照提取任务栏/属性面板控件并生成批处理点击片段
powershell -ExecutionPolicy Bypass -File .\scripts\parse_uia.ps1 -JsonPath uia.json -Mode taskbar -NameFilter "FlexSim" -BatchClick

# 4) 毫秒级像素差分校验并裁剪变化局部
powershell -ExecutionPolicy Bypass -File .\scripts\verify_diff.ps1 -Before prev.png -After latest.png -CropDiffPath diff_crop.png
```

---

## License

[MIT](LICENSE) © 2026 ddddyh

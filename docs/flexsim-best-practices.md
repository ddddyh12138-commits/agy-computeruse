# Antigravity 实现 Computer Use 与控制 FlexSim 2022 最佳实践

## 一、为什么不盲目堆砌纯视觉驱动？

在 Windows 平台上，纯视觉 Computer Use（每轮全屏截图 + 坐标点击）普遍存在单步延迟高、Token 消耗大、受 DPI 缩放影响严重以及中文输入法（IME）吞键等问题。对于 **FlexSim 2022** 这类 **Qt + Win32 + OpenGL 3D 视口** 混合架构软件，最佳方案不是叠加更多视觉驱动（如 `cua-driver` 或脆弱的第三方桥接），而是采用 **四层路由 + FlexSim 专属三层双通道**：

---

## 二、Antigravity 标准四层路由架构

```text
[用户任务]
   │
   ├─► Layer 0：CLI / API / 本地脚本（0 视觉成本，100% 确定性）
   ├─► Layer 1：浏览器 / CDP / OpenCLI / @playwright/cli（Web 与 SaaS 场景绝不走桌面点击）
   ├─► Layer 2：原生无障碍树主引擎（agent-desktop MCP，毫秒级 UIA + desktop_set_value）
   └─► Layer 3：混合视觉闭环（som_grid.ps1 外置标尺 + verify_diff.ps1 像素校验，3D/游戏兜底）
```

---

## 三、FlexSim 2022 专属三层双通道控制体系

在执行建模、连线或仿真实验前，通过 `flexsim_env_probe.ps1 -ProbeScriptMode` 自动探测本机授权状态，并按以下三通道协同工作：

1. **通道 1：FlexScript CLI 无头脚本通道（完整授权版直通）**
   - 利用 `flexsim_script_runner.py` 封装 `/maintenance nogui_disablemsg_runscript`，支持直接导出对象坐标/端口数量、重置并运行至指定仿真时间、导出统计 CSV/JSON。
2. **通道 2：`.fsx` XML 离线模型拓扑审计通道（全版本通用，零误差核验）**
   - FlexSim 支持将模型另存为纯文本 XML（`.fsx`）。`flexsim_fsx_inspector.py` 可直接解析对象清单、空间坐标、参数与 `A`（输入/输出）/ `S`（居中端口）连接，彻底避免从 3D 截图肉眼核对连线或遗漏多余操作员连接。
3. **通道 3：混合 UIA + 零遮挡 SoM + 原子批处理 GUI 通道（Express 评估版与 3D 交互主力）**
   - 基于 `agent-desktop`（`--headed`）主引擎，配合：
     - `som_grid.ps1`：28px 外置零遮挡标尺 + 局部 2x/3x 放大（精准拾取 `<15px` 控制点与路径）；
     - `parse_uia.ps1`：UTF-8 过滤右侧属性面板与任务栏控件；
     - `verify_diff.ps1`：`<200ms` 像素差分校验，连续两次 `NO_CHANGE` 自动熔断防死循环；
     - `flexsim_gui_helper.ps1`：一键生成抗中文 IME 粘贴、Qt `SpinBox` 逐键输入、属性面板 `吸管` 连线、3D 拖拽与 `ctrl+s` 磁盘落盘校验配方。

---

## 四、安全与稳定性铁律

1. **严守 Session 1 与 UIPI 边界**：禁止通过 `run_command`（Session 0）拉起 GUI 或发送按键；遇到提权弹窗（`E_ACCESSDENIED`）立即交由用户处理。
2. **测试号与沙盒隔离**：浏览器自动化建议使用仅登录测试号的独立 Chrome Profile；高风险自主任务建议在 Windows Sandbox 或独立虚拟机内运行，切勿安装来历不明的第三方“野壳子”MCP。
3. **仿真时钟与真实等待分离**：绝不能把 `desktop_wait(10000)` 当作仿真跑了 10 秒，必须读取 FlexSim 顶部真实仿真时钟与对象统计，并在 `ctrl+s` 后核验 `.fsm` 磁盘大小与修改时间。

param(
    [string]$ModelPath = "",
    [switch]$ProbeScriptMode,
    [int]$ProbeTimeoutSec = 10
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== FlexSim 2022 环境与双通道状态探测 ==="

# 1. 查找 FlexSim 可执行文件
$candidateRoots = @(
    "C:\Program Files\FlexSim 2022 Update 2",
    "C:\Program Files\FlexSim 2022"
)
$dynamicRoots = Get-ChildItem "C:\Program Files","C:\Program Files (x86)" -Filter "FlexSim*" -Directory | Select-Object -ExpandProperty FullName
$allRoots = ($candidateRoots + $dynamicRoots) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$flexExe = $null
foreach ($r in $allRoots) {
    $exe = Join-Path $r "program\flexsim.exe"
    if (Test-Path $exe) {
        $flexExe = $exe
        break
    }
}

if ($flexExe) {
    Write-Host "FLEXSIM_EXE=$flexExe"
} else {
    Write-Host "FLEXSIM_EXE=NOT_FOUND"
}

# 2. 检查运行中的 FlexSim 进程
$procs = Get-Process -Name "*flexsim*" | Select-Object Id, ProcessName, MainWindowHandle, MainWindowTitle
if ($procs) {
    foreach ($p in $procs) {
        $hasWin = ($p.MainWindowHandle -ne [IntPtr]::Zero)
        Write-Host ("RUNNING_PROC=pid:{0} name:{1} has_window:{2} title:{3}" -f $p.Id, $p.ProcessName, $hasWin, $p.MainWindowTitle)
    }
} else {
    Write-Host "RUNNING_PROC=NONE"
}

# 3. 检查显示器逻辑尺寸（高分屏物理分辨率以 agent-desktop desktop_list_displays 实测为准）
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
}
"@
$hdc = [DpiHelper]::GetDC([IntPtr]::Zero)
$dpiX = [DpiHelper]::GetDeviceCaps($hdc, 88)
[DpiHelper]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
$scalePct = [Math]::Round($dpiX / 96.0 * 100)
Write-Host ("DISPLAY_LOGICAL=width:{0} height:{1} dpi:{2} scale:{3}% (物理分辨率请以 agent-desktop desktop_list_displays 为准)" -f $screen.Bounds.Width, $screen.Bounds.Height, $dpiX, $scalePct)

# 4. 检查 Antigravity MCP 配置与可执行文件（优先检查 config，回退检查 antigravity）
$mcpCandidates = @(
    "$env:USERPROFILE\.gemini\config\mcp_config.json",
    "$env:USERPROFILE\.gemini\antigravity\mcp_config.json"
)
$mcpPath = $mcpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($mcpPath) {
    Write-Host "MCP_CONFIG=$mcpPath"
    $mcpJson = Get-Content $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $adCmd = $mcpJson.mcpServers.'agent-desktop'.command
    $ocuCmd = $mcpJson.mcpServers.'open-computer-use'.command
    if ($adCmd) { Write-Host ("MCP_AGENT_DESKTOP={0} exists:{1}" -f $adCmd, (Test-Path $adCmd)) }
    if ($ocuCmd) { Write-Host ("MCP_OPEN_CU={0} exists:{1}" -f $ocuCmd, (Test-Path $ocuCmd)) }
} else {
    Write-Host "MCP_CONFIG=NOT_FOUND"
}

# 5. 检查指定模型文件
if ($ModelPath -ne "") {
    if (Test-Path -LiteralPath $ModelPath) {
        $item = Get-Item -LiteralPath $ModelPath
        Write-Host ("MODEL_FILE={0} bytes:{1} mtime:{2}" -f $item.FullName, $item.Length, $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
    } else {
        Write-Host "MODEL_FILE=NOT_FOUND ($ModelPath)"
    }
}

# 6. 可选：无害探测 CLI 脚本模式是否可用（区分完整授权版 vs Express 受限版）
if ($ProbeScriptMode) {
    if (-not $flexExe) {
        Write-Host "MODE=NO_FLEXSIM_EXE"
        exit 1
    }
    $probeDir = Join-Path $env:TEMP ("flexsim_probe_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
    $scriptFile = Join-Path $probeDir "probe.txt"
    $markerFile = Join-Path $probeDir "probe_ok.txt"
    $markerEsc = $markerFile -replace "\\", "/"
    $fsCode = @"
fileopen("$markerEsc", "w");
filewrite("OK");
fileclose();
cmdexit();
"@
    [System.IO.File]::WriteAllText($scriptFile, $fsCode, [System.Text.Encoding]::ASCII)

    $proc = $null
    try {
        $argStr = "/maintenance nogui_disablemsg_runscript /scriptpath `"$scriptFile`""
        $proc = Start-Process -FilePath $flexExe -ArgumentList $argStr -PassThru -WindowStyle Hidden
        $finished = $proc.WaitForExit($ProbeTimeoutSec * 1000)
        if (-not $finished) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        if ($proc -and -not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path $markerFile) {
        Write-Host "MODE=FULL_SCRIPT_READY"
        Write-Host "RECOMMENDATION=当前环境支持 FlexScript CLI 无头脚本通道，可优先使用 flexsim_script_runner.py，建模与 3D 交互配合 agent-desktop + .fsx 审计。"
    } else {
        Write-Host "MODE=EXPRESS_OR_GUI_ONLY"
        Write-Host "RECOMMENDATION=CLI 无头脚本通道未响应（常见于 Express 版限制或缺少授权），请使用通道 3（agent-desktop + som_grid.ps1 + flexsim_gui_helper.ps1）配合通道 2（.fsx 离线审计）。"
    }

    Remove-Item -Path $probeDir -Recurse -Force -ErrorAction SilentlyContinue
}

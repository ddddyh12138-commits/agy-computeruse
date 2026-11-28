param(
    [ValidateSet("paste-field", "spinbox-num", "eyedropper-link", "drag-3d", "save-and-capture", "verify-fsm")]
    [string]$Recipe = "paste-field",
    [int]$X = 0,
    [int]$Y = 0,
    [int]$FromX = 0,
    [int]$FromY = 0,
    [int]$ToX = 0,
    [int]$ToY = 0,
    [string]$Text = "",
    [int]$Duration = 500,
    [int]$DropDelay = 500,
    [string]$ScreenshotPath = "",
    [string]$VerifyFsmPath = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($Recipe -eq "verify-fsm") {
    if (-not $VerifyFsmPath -or -not (Test-Path -LiteralPath $VerifyFsmPath)) {
        Write-Error "未找到目标 .fsm 文件：$VerifyFsmPath"
        exit 1
    }
    $item = Get-Item -LiteralPath $VerifyFsmPath
    [PSCustomObject]@{
        FullName      = $item.FullName
        Length        = $item.Length
        LastWriteTime = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
    } | ConvertTo-Json -Compress
    exit 0
}

$cmds = @()

switch ($Recipe) {
    "paste-field" {
        $cmds = @(
            @{ command = "clipboard-set"; args = @{ text = $Text } },
            @{ command = "wait"; args = @{ ms = 80 } },
            @{ command = "mouse-click"; args = @{ xy = "$X,$Y" } },
            @{ command = "wait"; args = @{ ms = 80 } },
            @{ command = "press"; args = @{ combo = "ctrl+a" } },
            @{ command = "press"; args = @{ combo = "ctrl+v" } },
            @{ command = "press"; args = @{ combo = "return" } },
            @{ command = "wait"; args = @{ ms = 150 } }
        )
    }
    "spinbox-num" {
        $cmds = @(
            @{ command = "mouse-click"; args = @{ xy = "$X,$Y"; count = 2 } },
            @{ command = "wait"; args = @{ ms = 80 } },
            @{ command = "press"; args = @{ combo = "ctrl+a" } },
            @{ command = "press"; args = @{ combo = "backspace" } }
        )
        foreach ($ch in $Text.ToCharArray()) {
            $cmds += @{ command = "press"; args = @{ combo = [string]$ch } }
        }
        $cmds += @{ command = "press"; args = @{ combo = "return" } }
        $cmds += @{ command = "wait"; args = @{ ms = 150 } }
    }
    "eyedropper-link" {
        $cmds = @(
            @{ command = "mouse-click"; args = @{ xy = "$FromX,$FromY" } },
            @{ command = "wait"; args = @{ ms = 120 } },
            @{ command = "mouse-click"; args = @{ xy = "$ToX,$ToY" } },
            @{ command = "wait"; args = @{ ms = 180 } }
        )
    }
    "drag-3d" {
        $cmds = @(
            @{ command = "drag"; args = @{ from_xy = "$FromX,$FromY"; to_xy = "$ToX,$ToY"; duration = $Duration; drop_delay = $DropDelay } },
            @{ command = "wait"; args = @{ ms = 200 } },
            @{ command = "mouse-click"; args = @{ xy = "$ToX,$ToY"; button = "right" } },
            @{ command = "wait"; args = @{ ms = 100 } }
        )
    }
    "save-and-capture" {
        $cmds = @(
            @{ command = "press"; args = @{ combo = "ctrl+s" } },
            @{ command = "wait"; args = @{ ms = 600 } }
        )
        if ($ScreenshotPath -ne "") {
            $cmds += @{ command = "screenshot"; args = @{ screen = 0; output_path = $ScreenshotPath } }
        }
    }
}

$cmds | ConvertTo-Json -Depth 5 -Compress

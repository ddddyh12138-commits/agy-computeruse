param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$XMin = 0,
    [int]$XMax = 2560,
    [int]$YMin = 0,
    [int]$YMax = 1600,
    [int]$Step = 50,
    [int]$Scale = 1,
    [switch]$Overview,
    [string]$Regions = "",
    [string]$Markers = "",
    [string]$SnapshotJson = ""
)

Add-Type -AssemblyName System.Drawing

$srcBmp = [System.Drawing.Bitmap]::FromFile($InputPath)
$rulerSize = 28

$parsedMarkers = @()
if ($Markers -ne "") {
    foreach ($m in ($Markers -split ";")) {
        $m = $m.Trim()
        if ($m -eq "") { continue }
        $parts = $m -split ":", 2
        $coords = $parts[0] -split ","
        if ($coords.Count -ge 2) {
            $parsedMarkers += [PSCustomObject]@{
                X = [int]$coords[0].Trim()
                Y = [int]$coords[1].Trim()
                Label = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "$($coords[0]),$($coords[1])" }
            }
        }
    }
}

$somNodes = @()
if ($SnapshotJson -ne "" -and (Test-Path $SnapshotJson)) {
    $doc = ([System.IO.File]::ReadAllText($SnapshotJson, [System.Text.Encoding]::UTF8)) | ConvertFrom-Json
    function Collect-SoM($Node) {
        if ($null -eq $Node) { return }
        $b = $Node.bounds
        $ref = [string]$Node.ref_id
        if ($null -ne $b -and $ref -ne "" -and $b.width -gt 0 -and $b.height -gt 0) {
            $script:somNodes += [PSCustomObject]@{
                X = [double]$b.x; Y = [double]$b.y; W = [double]$b.width; H = [double]$b.height
                CX = $b.x + $b.width / 2.0; CY = $b.y + $b.height / 2.0
                Tag = ($ref -split ":")[-1]
            }
        }
        if ($null -ne $Node.children) {
            foreach ($c in $Node.children) { Collect-SoM $c }
        }
    }
    Collect-SoM $doc.data.tree
}

function Render-RulerTile {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$RX0, [int]$RY0, [int]$RX1, [int]$RY1,
        [int]$RStep, [double]$RScale, [string]$Title
    )
    $x0 = [Math]::Max(0, $RX0)
    $y0 = [Math]::Max(0, $RY0)
    $x1 = [Math]::Min($Source.Width, $RX1)
    $y1 = [Math]::Min($Source.Height, $RY1)
    $srcW = $x1 - $x0
    $srcH = $y1 - $y0
    if ($srcW -le 0 -or $srcH -le 0) { throw "Invalid crop region: ($x0,$y0)-($x1,$y1)" }

    $dstW = [int][Math]::Round($srcW * $RScale)
    $dstH = [int][Math]::Round($srcH * $RScale)
    $titleH = if ($Title -ne "") { 18 } else { 0 }
    $ox = $rulerSize
    $oy = $rulerSize + $titleH
    $totalW = $ox + $dstW + 12
    $totalH = $oy + $dstH + 8

    $tile = New-Object System.Drawing.Bitmap($totalW, $totalH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($tile)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.Clear([System.Drawing.Color]::FromArgb(245, 246, 248))

    $srcRect = New-Object System.Drawing.Rectangle($x0, $y0, $srcW, $srcH)
    $dstRect = New-Object System.Drawing.Rectangle($ox, $oy, $dstW, $dstH)
    $g.DrawImage($Source, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::Default
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit

    $penR = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(165, 220, 30, 30), 1)
    $penB = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(165, 20, 70, 220), 1)
    $penG = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210, 0, 170, 60), 2)
    $penM = New-Object System.Drawing.Pen([System.Drawing.Color]::Magenta, 2)
    $penTickR = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 1)
    $penTickB = New-Object System.Drawing.Pen([System.Drawing.Color]::Blue, 1)
    $font = New-Object System.Drawing.Font('Consolas', 8, [System.Drawing.FontStyle]::Bold)
    $titleFont = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Bold)
    $tagBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 20, 20, 20))

    if ($Title -ne "") {
        $g.DrawString("$Title [$x0..$x1, $y0..$y1] x$RScale step=$RStep", $titleFont, [System.Drawing.Brushes]::Black, 4, 2)
    }

    $col = 0
    for ($x = $x0; $x -le $x1; $x += $RStep) {
        $dx = [float]($ox + ($x - $x0) * $RScale)
        $g.DrawLine($penR, $dx, [float]$oy, $dx, [float]($oy + $dstH))
        $g.DrawLine($penTickR, $dx, [float]($oy - 5), $dx, [float]$oy)
        if ($RStep * $RScale -ge 32 -or ($col % 2 -eq 0)) {
            $lbl = $x.ToString()
            $sz = $g.MeasureString($lbl, $font)
            $lx = [Math]::Max(2, [Math]::Min($totalW - $sz.Width - 2, $dx - $sz.Width / 2.0))
            $ly = if ($col % 2 -eq 0) { $titleH + 1 } else { $titleH + 12 }
            $g.DrawString($lbl, $font, [System.Drawing.Brushes]::DarkRed, [float]$lx, [float]$ly)
        }
        $col++
    }

    for ($y = $y0; $y -le $y1; $y += $RStep) {
        $dy = [float]($oy + ($y - $y0) * $RScale)
        $g.DrawLine($penB, [float]$ox, $dy, [float]($ox + $dstW), $dy)
        $g.DrawLine($penTickB, [float]($ox - 5), $dy, [float]$ox, $dy)
        $lbl = $y.ToString()
        $sz = $g.MeasureString($lbl, $font)
        $lx = [Math]::Max(1, $ox - $sz.Width - 5)
        $ly = [Math]::Max([float]$oy - 4, [Math]::Min($totalH - $sz.Height - 1, $dy - $sz.Height / 2.0))
        $g.DrawString($lbl, $font, [System.Drawing.Brushes]::DarkBlue, [float]$lx, [float]$ly)
    }

    foreach ($n in $somNodes) {
        if ($n.CX -ge $x0 -and $n.CX -le $x1 -and $n.CY -ge $y0 -and $n.CY -le $y1) {
            $bx = [float]($ox + ($n.X - $x0) * $RScale)
            $by = [float]($oy + ($n.Y - $y0) * $RScale)
            $bw = [float]($n.W * $RScale)
            $bh = [float]($n.H * $RScale)
            $g.DrawRectangle($penG, $bx, $by, $bw, $bh)
            $g.DrawString($n.Tag, $font, [System.Drawing.Brushes]::DarkGreen, $bx + 1, [Math]::Max([float]$oy, $by - 12))
        }
    }

    foreach ($mk in $parsedMarkers) {
        if ($mk.X -ge $x0 -and $mk.X -le $x1 -and $mk.Y -ge $y0 -and $mk.Y -le $y1) {
            $mx = [float]($ox + ($mk.X - $x0) * $RScale)
            $my = [float]($oy + ($mk.Y - $y0) * $RScale)
            $g.DrawEllipse($penM, $mx - 7, $my - 7, 14, 14)
            $g.DrawLine($penM, $mx - 11, $my, $mx + 11, $my)
            $g.DrawLine($penM, $mx, $my - 11, $mx, $my + 11)
            $txt = "$($mk.Label)($($mk.X),$($mk.Y))"
            $sz = $g.MeasureString($txt, $font)
            $tx = [Math]::Min($totalW - $sz.Width - 4, $mx + 9)
            $ty = [Math]::Max([float]$oy, $my - 14)
            $g.FillRectangle($tagBg, $tx, $ty, $sz.Width + 2, $sz.Height)
            $g.DrawString($txt, $font, [System.Drawing.Brushes]::White, $tx + 1, $ty)
        }
    }

    $penR.Dispose(); $penB.Dispose(); $penG.Dispose(); $penM.Dispose()
    $penTickR.Dispose(); $penTickB.Dispose(); $font.Dispose(); $titleFont.Dispose(); $tagBg.Dispose()
    $g.Dispose()
    return $tile
}

if ($Overview) {
    $tile = Render-RulerTile -Source $srcBmp -RX0 0 -RY0 0 -RX1 $srcBmp.Width -RY1 $srcBmp.Height -RStep 100 -RScale 0.5 -Title "OVERVIEW"
    $tile.Save($OutputPath)
    $outW = $tile.Width; $outH = $tile.Height
    $tile.Dispose()
} elseif ($Regions -ne "") {
    $tiles = @()
    foreach ($seg in ($Regions -split ";")) {
        $seg = $seg.Trim()
        if ($seg -eq "") { continue }
        $parts = $seg -split ":", 2
        $title = if ($parts.Count -eq 2) { $parts[0].Trim() } else { "ROI" }
        $nums = ($parts[-1] -split ",") | ForEach-Object { [int]$_.Trim() }
        if ($nums.Count -lt 4) { throw "Invalid region spec: $seg" }
        $rStep = if ($nums.Count -ge 5) { $nums[4] } else { $Step }
        $rScale = if ($nums.Count -ge 6) { [double]$nums[5] } else { [double]$Scale }
        $tiles += Render-RulerTile -Source $srcBmp -RX0 $nums[0] -RY0 $nums[1] -RX1 $nums[2] -RY1 $nums[3] -RStep $rStep -RScale $rScale -Title $title
    }
    $totalW = ($tiles | Measure-Object -Property Width -Sum).Sum + 8 * ([Math]::Max(0, $tiles.Count - 1))
    $maxH = ($tiles | Measure-Object -Property Height -Maximum).Maximum
    $canvas = New-Object System.Drawing.Bitmap($totalW, $maxH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cg = [System.Drawing.Graphics]::FromImage($canvas)
    $cg.Clear([System.Drawing.Color]::FromArgb(230, 232, 236))
    $cx = 0
    foreach ($t in $tiles) {
        $cg.DrawImage($t, $cx, 0)
        $cx += $t.Width + 8
        $t.Dispose()
    }
    $cg.Dispose()
    $canvas.Save($OutputPath)
    $outW = $canvas.Width; $outH = $canvas.Height
    $canvas.Dispose()
} else {
    $tile = Render-RulerTile -Source $srcBmp -RX0 $XMin -RY0 $YMin -RX1 $XMax -RY1 $YMax -RStep $Step -RScale ([double]$Scale) -Title ""
    $tile.Save($OutputPath)
    $outW = $tile.Width; $outH = $tile.Height
    $tile.Dispose()
}

$srcBmp.Dispose()
Write-Output "OK: $OutputPath ($outW x $outH)"
